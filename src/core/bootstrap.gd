extends Node

const MatchScreen = preload("res://src/ui/match_screen.gd")
const DeckbuilderScreen = preload("res://src/ui/deckbuilder_screen.gd")


func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		print("Bootstrap scene ready (headless).")
		return
	var tabs := TabContainer.new()
	tabs.name = "Screens"
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tabs)

	var match_screen := MatchScreen.new()
	match_screen.name = "Match"
	tabs.add_child(match_screen)

	var deckbuilder_screen := DeckbuilderScreen.new()
	deckbuilder_screen.name = "Deckbuilder"
	tabs.add_child(deckbuilder_screen)
