extends SceneTree

const CardDisplayComponentClass = preload("res://src/ui/components/CardDisplayComponent.gd")
const CARD_DISPLAY_SCENE := preload("res://scenes/ui/components/CardDisplayComponent.tscn")
const CARD_SIZE := Vector2(440, 680)
const OUT_PATH := "res://esl_template_preview.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(CARD_SIZE.x * 2 + 32), int(CARD_SIZE.y + 32))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.14, 1.0)
	bg.size = Vector2(viewport.size.x, viewport.size.y)
	viewport.add_child(bg)

	var default_card := CARD_DISPLAY_SCENE.instantiate() as CardDisplayComponentClass
	default_card.size = CARD_SIZE
	default_card.custom_minimum_size = CARD_SIZE
	default_card.position = Vector2(16, 16)
	viewport.add_child(default_card)

	var tpl_card := CARD_DISPLAY_SCENE.instantiate() as CardDisplayComponentClass
	tpl_card.size = CARD_SIZE
	tpl_card.custom_minimum_size = CARD_SIZE
	tpl_card.position = Vector2(CARD_SIZE.x + 32, 16)
	viewport.add_child(tpl_card)
	tpl_card.set_use_esl_template(true)

	await process_frame
	await process_frame

	var sample_card := {
		"instance_id": "sample_mono_neutral",
		"name": "Forgotten Hero",
		"card_type": "creature",
		"cost": 5,
		"power": 3,
		"health": 4,
		"rarity": "epic",
		"subtypes": ["wraith"],
		"attributes": ["neutral"],
		"rules_text": "[Summon]: Draw a card.\nLast Gasp: Draw a card.",
	}
	default_card.apply_card(sample_card, CardDisplayComponentClass.PRESENTATION_FULL)
	tpl_card.apply_card(sample_card, CardDisplayComponentClass.PRESENTATION_FULL)

	# Let layout and deferred font fitting settle.
	for i in 6:
		await process_frame

	var img := viewport.get_texture().get_image()
	if img == null:
		push_error("Viewport image was null.")
		quit(1)
		return
	var global_out := ProjectSettings.globalize_path(OUT_PATH)
	var err := img.save_png(global_out)
	if err != OK:
		push_error("Failed to save preview PNG: %s" % err)
		quit(1)
		return
	print("ESL_TEMPLATE_PREVIEW_SAVED ", global_out)
	quit(0)
