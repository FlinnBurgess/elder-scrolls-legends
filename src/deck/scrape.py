import requests
from bs4 import BeautifulSoup
import csv
import re
import time
from urllib.parse import quote

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
}

def get_all_card_urls_via_api():
    """Uses the MediaWiki API to fetch all card article titles cleanly."""
    print("Talking directly to the UESP API to get the master card list...")
    card_urls = []
    
    api_endpoint = "https://en.uesp.net/w/api.php"
    params = {
        "action": "query",
        "list": "categorymembers",
        "cmtitle": "Category:Legends-Cards",
        "cmlimit": "500",  
        "format": "json"
    }

    while True:
        response = requests.get(api_endpoint, params=params, headers=HEADERS)
        data = response.json()

        for member in data['query']['categorymembers']:
            title = member['title']
            if title.startswith('Legends:'):
                formatted_title = quote(title.replace(' ', '_'))
                card_urls.append(f"https://en.uesp.net/wiki/{formatted_title}")

        if 'continue' in data:
            params['cmcontinue'] = data['continue']['cmcontinue']
            print(f" -> Found {len(card_urls)} cards so far, asking for the next batch...")
        else:
            break

    print(f"\nAPI Success! Retrieved exactly {len(card_urls)} unique card URLs.")
    return card_urls

def scrape_card_data(url):
    """Visits a card page and extracts the specified attributes from the infobox."""
    response = requests.get(url, headers=HEADERS)
    soup = BeautifulSoup(response.text, 'html.parser')
    
    table = soup.find('table', class_=re.compile(r'wikitable.*infobox'))
    if not table:
        return None

    # Added 'Availability' to the data dictionary
    data = {
        'URL': url,
        'Name': '',
        'Type': '',
        'Subtype': '',
        'Unique': 'False',
        'Deck code ID': '',
        'Card Set': '',
        'Attribute(s)': '',
        'Magicka Cost': '',
        'Power': '',
        'Health': '',
        'Rarity': '',
        'Availability': '',
        'Card Text': ''
    }

    try:
        first_th = table.find('th')
        if first_th:
            data['Name'] = first_th.contents[0].strip() if first_th.contents else ""
            
            font_tag = first_th.find('font')
            if font_tag:
                raw_type = font_tag.text.replace('\xa0', ' ').strip()
                match = re.search(r'(.*?)\s*\((.*?)\)', raw_type)
                if match:
                    data['Type'] = match.group(1).strip()
                    data['Subtype'] = match.group(2).strip()
                else:
                    data['Type'] = raw_type

        if table.find(lambda t: t.name == 'th' and 'Unique' in t.text):
            data['Unique'] = 'True'

        rows = table.find_all('tr')
        for tr in rows:
            ths = tr.find_all('th')
            tds = tr.find_all('td')

            if len(ths) == 1 and len(tds) == 1:
                key = ths[0].text.strip()
                td_element = tds[0]
                val = td_element.text.strip()
                
                if "Magicka Cost" in key:
                    data['Magicka Cost'] = val
                elif "Deck code ID" in key:
                    data['Deck code ID'] = val
                elif "Card Set" in key:
                    data['Card Set'] = val
                elif "Attribute" in key:
                    data['Attribute(s)'] = val
                
                # NEW LOGIC: Handle Availability
                elif "Availability" in key:
                    data['Availability'] = val
                    
                # Handle "Class" rows by parsing the image icons
                elif "Class" in key:
                    extracted_attrs = []
                    target_attrs = ['Strength', 'Intelligence', 'Willpower', 'Agility', 'Endurance', 'Neutral']
                    
                    for img in td_element.find_all('img'):
                        img_src = img.get('src', '').lower()
                        img_alt = img.get('alt', '').lower()
                        
                        for attr in target_attrs:
                            if attr.lower() in img_src or attr.lower() in img_alt:
                                if attr not in extracted_attrs:
                                    extracted_attrs.append(attr)
                    
                    data['Attribute(s)'] = ', '.join(extracted_attrs)
                
                elif "Rarity" in key:
                    data['Rarity'] = val

            elif len(ths) == 2 and len(tds) == 2:
                for i in range(2):
                    key = ths[i].text.strip()
                    val = tds[i].text.strip()
                    if "Power" in key:
                        data['Power'] = val
                    elif "Health" in key:
                        data['Health'] = val

        last_row = rows[-1]
        if not last_row.find('th') and last_row.find('td'):
            raw_text = last_row.text.strip()
            data['Card Text'] = re.sub(r'\s+', ' ', raw_text)

    except Exception as e:
        print(f"Error parsing table on {url}: {e}")

    return data

def main():
    card_links = get_all_card_urls_via_api()
    
    if not card_links:
        print("No cards found. Exiting.")
        return

    csv_filename = "legends_cards_data.csv"
    
    # Added 'Availability' to the CSV headers
    fieldnames = ['URL', 'Name', 'Type', 'Subtype', 'Unique', 'Deck code ID',
                  'Card Set', 'Attribute(s)', 'Magicka Cost', 'Power', 'Health', 'Rarity', 'Availability', 'Card Text']

    with open(csv_filename, mode='w', newline='', encoding='utf-8') as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()

        print(f"Scraping HTML tables for {len(card_links)} cards. This will take a few minutes...")
        for i, url in enumerate(card_links, 1):
            data = scrape_card_data(url)
            if data:
                writer.writerow(data)
            
            if i % 50 == 0:
                print(f"Processed {i}/{len(card_links)} cards...")
            
            time.sleep(0.2)

    print(f"\nScraping complete! Data saved to {csv_filename}")

if __name__ == "__main__":
    main()