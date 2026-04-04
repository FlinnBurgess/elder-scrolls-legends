import re
import csv
import json
import os
import webbrowser
from difflib import SequenceMatcher
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GD_FILE = os.path.join(SCRIPT_DIR, "card_catalog.gd")
CSV_FILE = os.path.join(SCRIPT_DIR, "legends_cards_data.csv")
IGNORE_LIST_FILE = os.path.join(SCRIPT_DIR, "compare_ignore.json")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_ignore_list():
    if os.path.exists(IGNORE_LIST_FILE):
        with open(IGNORE_LIST_FILE, 'r', encoding='utf-8') as f:
            return set(name.lower() for name in json.load(f))
    return set()

def save_ignore_list(names):
    with open(IGNORE_LIST_FILE, 'w', encoding='utf-8') as f:
        json.dump(sorted(names), f, indent=2)

def clean_text(text):
    if not text:
        return ""
    text = text.replace('\\n', ' ').replace('\n', ' ').replace('~', '')
    return ' '.join(text.split()).strip()

def inline_diff(old, new):
    sm = SequenceMatcher(None, old, new)
    parts = []
    for op, i1, i2, j1, j2 in sm.get_opcodes():
        if op == 'equal':
            parts.append(old[i1:i2])
        elif op == 'replace':
            parts.append(f'<span style="background:#fbb;text-decoration:line-through">{old[i1:i2]}</span>')
            parts.append(f'<span style="background:#bfb">{new[j1:j2]}</span>')
        elif op == 'delete':
            parts.append(f'<span style="background:#fbb;text-decoration:line-through">{old[i1:i2]}</span>')
        elif op == 'insert':
            parts.append(f'<span style="background:#bfb">{new[j1:j2]}</span>')
    return ''.join(parts)

# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

def extract_card_templates(extra_data):
    templates = []
    idx = 0
    while True:
        start_idx = extra_data.find('"card_template"', idx)
        if start_idx == -1: break
        brace_idx = extra_data.find('{', start_idx)
        if brace_idx == -1: break
        open_braces = 0
        end_idx = -1
        for i in range(brace_idx, len(extra_data)):
            if extra_data[i] == '{': open_braces += 1
            elif extra_data[i] == '}':
                open_braces -= 1
                if open_braces == 0:
                    end_idx = i
                    break
        if end_idx != -1:
            templates.append(extra_data[brace_idx:end_idx+1])
            idx = end_idx + 1
        else:
            break
    return templates

def parse_gdscript(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    cards = {}
    pattern = re.compile(
        r'_seed\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*\[(.*?)\]\s*,\s*"([^"]+)"\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*\{(.*?)\}\s*\)',
        re.DOTALL
    )
    for match in pattern.finditer(content):
        card_id = match.group(1).strip()
        name = match.group(2).strip()
        name_key = name.lower()
        attributes_raw = match.group(3)
        card_type = match.group(4).strip().lower()
        cost = int(match.group(5))
        power = int(match.group(6))
        health = int(match.group(7))
        extra_data = match.group(8)
        attributes = [attr.strip(' "').lower() for attr in attributes_raw.split(',') if attr.strip()]

        # Strip nested card_template blocks so we only match top-level properties
        top_level_data = extra_data
        for t_str in extract_card_templates(extra_data):
            top_level_data = top_level_data.replace(t_str, '')

        rarity_match = re.search(r'"rarity"\s*:\s*"([^"]+)"', top_level_data)
        rarity = rarity_match.group(1).lower() if rarity_match else "common"

        subtypes_match = re.search(r'"subtypes"\s*:\s*\[(.*?)\]', top_level_data)
        race = ""
        if subtypes_match:
            races = [r.strip(' "') for r in subtypes_match.group(1).split(',') if r.strip()]
            race = ", ".join(races)

        unique_match = re.search(r'"is_unique"\s*:\s*(true|false)', top_level_data, re.IGNORECASE)
        is_unique = True if (unique_match and unique_match.group(1).lower() == 'true') else False

        rules_match = re.search(r'"rules_text"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"', top_level_data)
        rules_text = clean_text(rules_match.group(1)) if rules_match else ""

        dc_match = re.search(r'"deck_code_id"\s*:\s*"([^"]+)"', top_level_data)
        deck_code_id = dc_match.group(1) if dc_match else ""

        base_card = {
            "id": card_id, "name": name, "type": card_type,
            "attributes": set(attributes), "cost": cost, "power": power, "health": health,
            "rarity": rarity, "race": race.lower(), "unique": is_unique,
            "description": rules_text, "deck_code_id": deck_code_id, "is_base": True
        }
        if name_key not in cards:
            cards[name_key] = []
        cards[name_key].append(base_card)

        for t_str in extract_card_templates(extra_data):
            t_card = base_card.copy()
            t_card["is_base"] = False
            power_match = re.search(r'"power"\s*:\s*(\d+)', t_str)
            if power_match: t_card["power"] = int(power_match.group(1))
            health_match = re.search(r'"health"\s*:\s*(\d+)', t_str)
            if health_match: t_card["health"] = int(health_match.group(1))
            type_match = re.search(r'"card_type"\s*:\s*"([^"]+)"', t_str)
            if type_match: t_card["type"] = type_match.group(1).lower()
            subtypes_match = re.search(r'"subtypes"\s*:\s*\[(.*?)\]', t_str)
            if subtypes_match:
                races = [r.strip(' "') for r in subtypes_match.group(1).split(',') if r.strip()]
                t_card["race"] = ", ".join(races).lower()
            rules_match = re.search(r'"rules_text"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"', t_str)
            if rules_match: t_card["description"] = clean_text(rules_match.group(1))
            attr_match = re.search(r'"attributes"\s*:\s*\[(.*?)\]', t_str)
            if attr_match:
                t_attributes = [attr.strip(' "').lower() for attr in attr_match.group(1).split(',') if attr.strip()]
                t_card["attributes"] = set(t_attributes)
            t_dc_match = re.search(r'"deck_code_id"\s*:\s*"([^"]+)"', t_str)
            if t_dc_match: t_card["deck_code_id"] = t_dc_match.group(1)
            cards[name_key].append(t_card)
    return cards

def parse_csv(file_path):
    cards = {}
    with open(file_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = row.get("Name", "").strip()
            if not name: continue
            name_key = name.lower()
            url = row.get("URL", "").strip()
            card_type = row.get("Type", "").strip().lower()
            race = row.get("Subtype", "").strip().lower()
            is_unique = (row.get("Unique", "").strip().lower() == 'true')
            attributes_raw = row.get("Attribute(s)", "").strip().lower()
            attributes = set([attr.strip() for attr in re.split(r'\+|,', attributes_raw) if attr.strip()])
            cost_str = row.get("Magicka Cost", "").strip()
            power_str = row.get("Power", "").strip()
            health_str = row.get("Health", "").strip()
            cost = int(cost_str) if cost_str.isdigit() else 0
            power = int(power_str) if power_str.isdigit() else 0
            health = int(health_str) if health_str.isdigit() else 0
            rarity = row.get("Rarity", "").strip().lower() if row.get("Rarity", "").strip() else "common"
            desc_raw = row.get("Card Text", "").strip()
            availability = row.get("Availability", "").strip()
            csv_card = {
                "url": url, "name": name, "type": card_type, "attributes": attributes,
                "cost": cost, "power": power, "health": health, "rarity": rarity, "race": race,
                "unique": is_unique, "description": clean_text(desc_raw), "availability": availability
            }
            if name_key not in cards:
                cards[name_key] = []
            cards[name_key].append(csv_card)
    return cards

# ---------------------------------------------------------------------------
# Comparison
# ---------------------------------------------------------------------------

def compute_diffs(gd_card, csv_card):
    diffs = {}
    if gd_card["cost"] != csv_card["cost"]:
        diffs["Cost"] = {"text": f'GDScript: <b>{gd_card["cost"]}</b> | CSV: <b>{csv_card["cost"]}</b>', "val": csv_card["cost"]}
    if gd_card["type"] != csv_card["type"]:
        diffs["Type"] = {"text": f'GDScript: <b>{gd_card["type"]}</b> | CSV: <b>{csv_card["type"]}</b>', "val": csv_card["type"]}
    if gd_card["power"] != csv_card["power"]:
        diffs["Power"] = {"text": f'GDScript: <b>{gd_card["power"]}</b> | CSV: <b>{csv_card["power"]}</b>', "val": csv_card["power"]}
    if gd_card["health"] != csv_card["health"]:
        diffs["Health"] = {"text": f'GDScript: <b>{gd_card["health"]}</b> | CSV: <b>{csv_card["health"]}</b>', "val": csv_card["health"]}
    if gd_card["rarity"] != csv_card["rarity"]:
        diffs["Rarity"] = {"text": f'GDScript: <b>{gd_card["rarity"]}</b> | CSV: <b>{csv_card["rarity"]}</b>', "val": csv_card["rarity"]}
    # Unique mismatches are auto-fixed, not reported
    if gd_card["attributes"] != csv_card["attributes"]:
        gd_attr = ", ".join(gd_card["attributes"]) if gd_card["attributes"] else "None"
        csv_attr = ", ".join(csv_card["attributes"]) if csv_card["attributes"] else "None"
        diffs["Attributes"] = {"text": f'GDScript: <b>{gd_attr}</b> | CSV: <b>{csv_attr}</b>', "val": list(csv_card["attributes"])}
    if gd_card["race"] != csv_card["race"]:
        diffs["Race/Subtype"] = {"text": f'GDScript: <b>"{gd_card["race"]}"</b> | CSV: <b>"{csv_card["race"]}"</b>', "val": None}
    gd_desc_compare = re.sub(r'[\s\u00a0\u200b\u200c\u200d\ufeff]+', '', gd_card["description"]).rstrip('.').replace('\u2013', '-').replace('\u2014', '-').lower()
    csv_desc_compare = re.sub(r'[\s\u00a0\u200b\u200c\u200d\ufeff]+', '', csv_card["description"]).rstrip('.').replace('\u2013', '-').replace('\u2014', '-').lower()
    if gd_desc_compare != csv_desc_compare:
        diffs["Rules Text"] = {"text": inline_diff(gd_card["description"], csv_card["description"]), "val": None}
    gd_deck_code = gd_card.get("deck_code_id", "")
    csv_avail = csv_card.get("availability", "")
    gd_has_code = bool(gd_deck_code)
    csv_unobtainable = csv_avail.lower() in ["unobtainable", "created"]
    if gd_has_code and csv_unobtainable:
        diffs["Availability"] = {"text": f'GDScript: Has deck code "{gd_deck_code}" | CSV: {csv_avail}', "val": "REMOVE_DECK_CODE"}
    elif not gd_has_code and not csv_unobtainable:
        diffs["Availability"] = {"text": f'GDScript: No deck code | CSV: Available (Empty)', "val": None}
    return diffs

def collect_unique_fixes(gd_cards, csv_cards):
    fixes = []
    for name_key in gd_cards:
        if name_key not in csv_cards:
            continue
        for csv_data in csv_cards[name_key]:
            for gd_data in gd_cards[name_key]:
                if gd_data["unique"] != csv_data["unique"] and gd_data["is_base"]:
                    fixes.append({"card_id": gd_data["id"], "name": gd_data["name"], "new_value": csv_data["unique"]})
    return fixes

def apply_unique_fixes(gd_file_path, fixes):
    if not fixes:
        return
    with open(gd_file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    for fix in fixes:
        card_id = re.escape(fix["card_id"])
        if fix["new_value"]:
            pattern = re.compile(r'(_seed\(\s*"' + card_id + r'"[^)]*\{)', re.DOTALL)
            match = pattern.search(content)
            if match and '"is_unique"' not in content[match.start():content.find(')', match.end())]:
                content = content[:match.end()] + '"is_unique": true, ' + content[match.end():]
        else:
            pattern = re.compile(r'(_seed\(\s*"' + card_id + r'"[^)]*?)"is_unique"\s*:\s*true\s*,?\s*', re.DOTALL)
            content = pattern.sub(r'\1', content)
    with open(gd_file_path, 'w', encoding='utf-8') as f:
        f.write(content)

def compare_datasets(gd_cards, csv_cards, ignore_list=None):
    if ignore_list is None:
        ignore_list = set()
    discrepancies = []
    all_names = set(gd_cards.keys()).union(set(csv_cards.keys()))
    for name_key in sorted(all_names):
        if name_key in ignore_list:
            continue
        if name_key not in gd_cards:
            for csv_data in csv_cards[name_key]:
                csv_avail = csv_data.get("availability", "").lower()
                if csv_avail in ["unobtainable", "created"]:
                    continue
                discrepancies.append({"name": csv_data["name"], "url": csv_data.get("url", ""), "issue": "Missing in card_catalog.gd"})
            continue
        if name_key not in csv_cards:
            for gd_data in gd_cards[name_key]:
                discrepancies.append({"name": gd_data["name"], "url": "", "issue": "Missing in legends_cards_data.csv"})
            continue
        gd_list = gd_cards[name_key]
        csv_list = csv_cards[name_key]
        for csv_data in csv_list:
            best_diffs = None
            best_gd = None
            for gd_data in gd_list:
                diffs = compute_diffs(gd_data, csv_data)
                if len(diffs) == 0:
                    best_diffs = {}
                    break
                if best_diffs is None or len(diffs) < len(best_diffs):
                    best_diffs = diffs
                    best_gd = gd_data
            if best_diffs:
                discrepancies.append({
                    "name": csv_data["name"], "url": csv_data.get("url", ""),
                    "issue": "Data mismatch", "diffs": best_diffs,
                    "card_id": best_gd["id"], "is_base": best_gd["is_base"]
                })
    return discrepancies

# ---------------------------------------------------------------------------
# GDScript in-place fix helpers
# ---------------------------------------------------------------------------

def apply_fix_to_file(card_id, field, new_value):
    with open(GD_FILE, 'r', encoding='utf-8') as f:
        content = f.read()

    safe_id = re.escape(card_id)

    if field in ('Cost', 'Power', 'Health', 'Type'):
        regex = re.compile(
            r'(_seed\(\s*"' + safe_id + r'"\s*,\s*"[^"]+"\s*,\s*\[.*?\]\s*,\s*")'
            r'([^"]+)'
            r'("\s*,\s*)'
            r'(\d+)'
            r'(\s*,\s*)'
            r'(\d+)'
            r'(\s*,\s*)'
            r'(\d+)',
            re.DOTALL
        )
        def replacer(m):
            typ, cost, power, health = m.group(2), m.group(4), m.group(6), m.group(8)
            if field == 'Cost': cost = str(new_value)
            elif field == 'Power': power = str(new_value)
            elif field == 'Health': health = str(new_value)
            elif field == 'Type': typ = new_value
            return m.group(1) + typ + m.group(3) + cost + m.group(5) + power + m.group(7) + health
        content = regex.sub(replacer, content)

    elif field == 'Attributes':
        regex = re.compile(r'(_seed\(\s*"' + safe_id + r'"\s*,\s*"[^"]+"\s*,\s*)(\[.*?\])', re.DOTALL)
        attr_str = json.dumps(new_value)
        content = regex.sub(lambda m: m.group(1) + attr_str, content)

    elif field == 'Rarity':
        seed_re = re.compile(r'(_seed\(\s*"' + safe_id + r'"[\s\S]*?\{)', re.DOTALL)
        match = seed_re.search(content)
        if match:
            after = content[match.start():]
            prop_re = re.compile(r'("rarity"\s*:\s*)"[^"]+"')
            if prop_re.search(after):
                after = prop_re.sub(r'\1"' + new_value + '"', after, count=1)
            else:
                after = after[:match.end() - match.start()] + f'"rarity": "{new_value}", ' + after[match.end() - match.start():]
            content = content[:match.start()] + after

    elif field == 'Availability' and new_value == 'REMOVE_DECK_CODE':
        seed_re = re.compile(r'(_seed\(\s*"' + safe_id + r'"[\s\S]*?\{)', re.DOTALL)
        match = seed_re.search(content)
        if match:
            after = content[match.start():]
            remove_re = re.compile(r'"deck_code_id"\s*:\s*"[^"]+"\s*,?\s*')
            after = remove_re.sub('', after, count=1)
            content = content[:match.start()] + after

    with open(GD_FILE, 'w', encoding='utf-8') as f:
        f.write(content)

# ---------------------------------------------------------------------------
# HTML generation
# ---------------------------------------------------------------------------

def build_html(discrepancies):
    rows = ""
    for item in discrepancies:
        name = item["name"]
        issue = item["issue"]
        url = item.get("url", "")
        safe_name = name.replace("'", "\\'").replace('"', '&quot;')

        name_display = f'<a href="{url}" target="_blank"><strong>{name}</strong></a>' if url else f'<strong>{name}</strong>'

        if issue == "Data mismatch":
            details_list = []
            is_base = item.get("is_base", True)
            card_id = item.get("card_id", "")
            safe_card_id = card_id.replace('"', '&quot;')

            for field, diff_info in item.get("diffs", {}).items():
                diff_text = diff_info["text"]
                new_val = diff_info["val"]

                fix_btn = ""
                if new_val is not None and is_base and field in ["Cost", "Type", "Power", "Health", "Rarity", "Attributes"]:
                    payload = json.dumps({"card_id": card_id, "field": field, "value": new_val})
                    safe_payload = payload.replace("&", "&amp;").replace('"', '&quot;').replace("'", "&#39;")
                    fix_btn = f'<button class="fix-btn" data-payload="{safe_payload}" onclick="applyFix(this)">Fix {field}</button>'

                elif new_val == "REMOVE_DECK_CODE" and is_base:
                    payload = json.dumps({"card_id": card_id, "field": "Availability", "value": "REMOVE_DECK_CODE"})
                    safe_payload = payload.replace("&", "&amp;").replace('"', '&quot;').replace("'", "&#39;")
                    fix_btn = f'<button class="fix-btn" data-payload="{safe_payload}" onclick="applyFix(this)">Remove Deck Code</button>'

                elif not is_base and new_val is not None:
                    fix_btn = '<span class="warning">(Nested template mismatch - manual fix required)</span>'

                details_list.append(f'<div class="detail-row"><div><i>{field}:</i><br>{diff_text}</div> <div>{fix_btn}</div></div>')

            details = ''.join(details_list)
            css_class = "mismatch"
        else:
            details = f'<span>{issue}</span>'
            css_class = "missing"

        rows += f'''
            <tr id="row-{safe_name}">
                <td>{name_display}<br><button class="ignore-btn" onclick="ignoreCard(this, '{safe_name}')">Ignore</button></td>
                <td><span class="{css_class}">{issue}</span></td>
                <td>{details}</td>
            </tr>'''

    return f'''<!DOCTYPE html>
<html>
<head>
    <title>Card Discrepancy Fixer</title>
    <style>
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 30px; background-color: #f4f7f6; color: #333; }}
        h1 {{ text-align: center; color: #2c3e50; }}
        .status-bar {{ position: sticky; top: 0; background: #2c3e50; padding: 10px 20px; text-align: center; z-index: 1000; border-radius: 5px; margin-bottom: 20px; color: white; }}
        .status-bar span {{ margin: 0 15px; }}
        table {{ width: 100%; border-collapse: collapse; background-color: #fff; box-shadow: 0 4px 8px rgba(0,0,0,0.05); }}
        th, td {{ border: 1px solid #e0e0e0; padding: 15px; text-align: left; vertical-align: top; }}
        th {{ background-color: #2980b9; color: white; text-transform: uppercase; font-size: 0.9em; }}
        tr:nth-child(even) {{ background-color: #f9f9f9; }}
        a {{ color: #2980b9; text-decoration: none; }}
        a:hover {{ text-decoration: underline; }}
        .missing {{ color: #e74c3c; font-weight: bold; }}
        .mismatch {{ color: #f39c12; font-weight: bold; }}
        .detail-row {{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; padding-bottom: 8px; border-bottom: 1px solid #eee; }}
        .detail-row:last-child {{ border-bottom: none; margin-bottom: 0; padding-bottom: 0; }}
        .fix-btn {{ background-color: #3498db; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer; font-size: 0.85em; transition: background 0.2s; }}
        .fix-btn:hover {{ background-color: #2980b9; }}
        .fix-btn.fixed {{ background-color: #27ae60; cursor: default; }}
        .ignore-btn {{ background-color: #95a5a6; color: white; border: none; padding: 4px 10px; border-radius: 3px; cursor: pointer; font-size: 0.8em; margin-top: 8px; }}
        .ignore-btn:hover {{ background-color: #7f8c8d; }}
        .warning {{ font-size: 0.8em; color: #7f8c8d; font-style: italic; }}
    </style>
</head>
<body>
    <div class="status-bar">
        <span>Discrepancies: {len(discrepancies)}</span>
    </div>
    <h1>Card Discrepancy Fixer</h1>
    <table>
        <tr>
            <th style="width: 20%;">Card Name</th>
            <th style="width: 15%;">Issue</th>
            <th style="width: 65%;">Details & Fixes</th>
        </tr>
        {rows}
    </table>
    <script>
        async function applyFix(btn) {{
            const payload = JSON.parse(btn.getAttribute('data-payload'));
            btn.disabled = true;
            btn.textContent = '...';
            const resp = await fetch('/fix', {{
                method: 'POST',
                headers: {{'Content-Type': 'application/json'}},
                body: JSON.stringify(payload)
            }});
            if (resp.ok) {{
                btn.textContent = 'Fixed';
                btn.classList.add('fixed');
            }} else {{
                btn.textContent = 'Error';
                btn.disabled = false;
            }}
        }}

        async function ignoreCard(btn, cardName) {{
            btn.disabled = true;
            btn.textContent = '...';
            const resp = await fetch('/ignore', {{
                method: 'POST',
                headers: {{'Content-Type': 'application/json'}},
                body: JSON.stringify({{name: cardName}})
            }});
            if (resp.ok) {{
                btn.closest('tr').remove();
            }}
        }}
    </script>
</body>
</html>'''

# ---------------------------------------------------------------------------
# HTTP Server
# ---------------------------------------------------------------------------

class Handler(BaseHTTPRequestHandler):
    discrepancies = []
    ignore_list = set()

    def do_GET(self):
        html = build_html(self.discrepancies)
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(html.encode('utf-8'))

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = json.loads(self.rfile.read(length))

        if self.path == '/fix':
            try:
                apply_fix_to_file(body['card_id'], body['field'], body['value'])
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'ok')
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(e).encode())

        elif self.path == '/ignore':
            name = body['name'].lower()
            Handler.ignore_list.add(name)
            save_ignore_list(Handler.ignore_list)
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'ok')

        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # silence request logs

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    gd_cards = parse_gdscript(GD_FILE)
    csv_cards = parse_csv(CSV_FILE)

    unique_fixes = collect_unique_fixes(gd_cards, csv_cards)
    if unique_fixes:
        apply_unique_fixes(GD_FILE, unique_fixes)
        print(f"Auto-fixed 'unique' on {len(unique_fixes)} card(s): {', '.join(f['name'] for f in unique_fixes)}")
        gd_cards = parse_gdscript(GD_FILE)

    ignore_list = load_ignore_list()
    discrepancies = compare_datasets(gd_cards, csv_cards, ignore_list)

    Handler.discrepancies = discrepancies
    Handler.ignore_list = ignore_list

    port = 8787
    server = HTTPServer(('localhost', port), Handler)
    print(f"Serving discrepancy report at http://localhost:{port}")
    print(f"Total discrepancies: {len(discrepancies)}")
    print("Press Ctrl+C to stop")
    webbrowser.open(f'http://localhost:{port}')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
        server.server_close()
