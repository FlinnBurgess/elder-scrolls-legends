extends SceneTree

const BOOTSTRAP_SCENE := preload("res://scenes/bootstrap/bootstrap.tscn")


func _initialize() -> void:
	var instance := BOOTSTRAP_SCENE.instantiate()
	if instance == null:
		push_error("Failed to instantiate bootstrap scene.")
		quit(1)
		return

	get_root().add_child(instance)
	call_deferred("_verify", instance)


func _verify(instance: Node) -> void:
	var tabs := instance.get_node_or_null("Screens")
	if tabs == null:
		push_error("Bootstrap should create a tab container named `Screens`.")
		quit(1)
		return
	if tabs.get_child_count() < 2:
		push_error("Bootstrap should expose both match and deckbuilder tabs.")
		quit(1)
		return
	if tabs.get_child(0).name != "Match" or tabs.get_child(1).name != "Deckbuilder":
		push_error("Bootstrap tab order should be Match then Deckbuilder.")
		quit(1)
		return
	print("BOOTSTRAP_SMOKE_OK")
	quit(0)