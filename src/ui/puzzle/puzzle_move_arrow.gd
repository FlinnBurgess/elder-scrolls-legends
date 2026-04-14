class_name PuzzleMoveArrow
extends Control

## Full-rect overlay that draws a gold arrow from `source_global_pos`
## to the current mouse position. Used by the puzzle/test-match builder
## to visualise an in-progress creature move.

const UITheme = preload("res://src/ui/ui_theme.gd")

const LINE_WIDTH := 4.0
const HEAD_SIZE := 22.0
const SOURCE_DOT_RADIUS := 8.0

var source_global_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 50


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var from := source_global_pos - global_position
	var to := get_local_mouse_position()
	if from.distance_to(to) < 2.0:
		draw_circle(from, SOURCE_DOT_RADIUS, UITheme.GOLD_BRIGHT)
		return

	var color := UITheme.GOLD_BRIGHT
	draw_line(from, to, color, LINE_WIDTH, true)

	# Source marker
	draw_circle(from, SOURCE_DOT_RADIUS, color)

	# Arrowhead
	var dir := (to - from).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var back := to - dir * HEAD_SIZE
	draw_line(to, back + perp * (HEAD_SIZE * 0.5), color, LINE_WIDTH, true)
	draw_line(to, back - perp * (HEAD_SIZE * 0.5), color, LINE_WIDTH, true)
