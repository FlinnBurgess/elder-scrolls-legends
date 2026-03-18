class_name DeckbuilderScreen
extends Control

const DeckListScreenClass = preload("res://src/ui/deck_list_screen.gd")
const DeckEditorScreenClass = preload("res://src/ui/deck_editor_screen.gd")
const DeckPersistenceClass = preload("res://src/deck/deck_persistence.gd")

var _deck_list_screen: Control
var _deck_editor_screen: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_show_deck_list()


func _show_deck_list() -> void:
	if _deck_editor_screen != null:
		_deck_editor_screen.queue_free()
		_deck_editor_screen = null

	if _deck_list_screen == null:
		_deck_list_screen = DeckListScreenClass.new()
		_deck_list_screen.edit_deck_requested.connect(_on_edit_deck_requested)
		add_child(_deck_list_screen)
	else:
		_deck_list_screen.visible = true
		_deck_list_screen.refresh()


func _show_deck_editor(deck_name: String) -> void:
	if _deck_list_screen != null:
		_deck_list_screen.visible = false

	_deck_editor_screen = DeckEditorScreenClass.new()
	_deck_editor_screen.done_pressed.connect(_on_editor_done)
	_deck_editor_screen.cancel_pressed.connect(_on_editor_cancel)
	add_child(_deck_editor_screen)

	var definition: Dictionary = DeckPersistenceClass.load_deck(deck_name)
	_deck_editor_screen.load_deck(deck_name, definition)


func _on_edit_deck_requested(deck_name: String) -> void:
	_show_deck_editor(deck_name)


func _on_editor_done() -> void:
	_show_deck_list()


func _on_editor_cancel() -> void:
	_show_deck_list()
