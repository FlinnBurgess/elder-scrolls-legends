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
	var main_menu := instance.get_node_or_null("MainMenu")
	if main_menu == null:
		push_error("Bootstrap should create a main menu named `MainMenu`.")
		quit(1)
		return
	if not main_menu.visible:
		push_error("Main menu should be visible on launch.")
		quit(1)
		return
	print("BOOTSTRAP_SMOKE_OK")
	quit(0)
