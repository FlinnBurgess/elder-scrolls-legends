extends Node


func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		print("Bootstrap scene ready (headless).")