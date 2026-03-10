extends SceneTree

const BOOTSTRAP_SCENE := preload("res://scenes/bootstrap/bootstrap.tscn")


func _initialize() -> void:
	var instance := BOOTSTRAP_SCENE.instantiate()
	if instance == null:
		push_error("Failed to instantiate bootstrap scene.")
		quit(1)
		return

	get_root().add_child(instance)
	call_deferred("_finish")


func _finish() -> void:
	print("BOOTSTRAP_SMOKE_OK")
	quit(0)