class_name DraggableFrame
extends Control

# A self-contained Control that can be dragged to move and resized via four
# corner handles. Emits `rect_changed(rect: Rect2)` whenever position/size
# changes. The frame draws a translucent fill, a dashed outline, four small
# corner handles, and a centered label set via `label_text`.

signal rect_changed(rect: Rect2)

@export var label_text: String = "":
	set(value):
		label_text = value
		queue_redraw()
@export var handle_size: float = 12.0
@export var fill_color: Color = Color(0.95, 0.88, 0.6, 0.10)
@export var outline_color: Color = Color(0.95, 0.88, 0.6, 0.85)
@export var handle_color: Color = Color(0.95, 0.88, 0.6, 1.0)
@export var label_color: Color = Color(0.97, 0.95, 0.9, 0.95)

const _MIN_DIM := 8.0

# Internal drag state
var _dragging := false
var _resizing_corner := -1  # -1 = none, 0=TL, 1=TR, 2=BL, 3=BR
var _drag_anchor_local := Vector2.ZERO  # cursor offset within self when drag began
var _drag_start_position := Vector2.ZERO
var _drag_start_size := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local: Vector2 = event.position
			_resizing_corner = _hit_test_corner(local)
			_dragging = _resizing_corner == -1
			_drag_anchor_local = local
			_drag_start_position = position
			_drag_start_size = size
			get_viewport().set_input_as_handled()
		else:
			_dragging = false
			_resizing_corner = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _dragging:
			# Move so that the cursor stays at the same local offset within the frame.
			var delta: Vector2 = event.position - _drag_anchor_local
			position += delta
			rect_changed.emit(Rect2(position, size))
			get_viewport().set_input_as_handled()
			queue_redraw()
		elif _resizing_corner != -1:
			var delta_resize: Vector2 = event.position - _drag_anchor_local
			var new_pos: Vector2 = _drag_start_position
			var new_size: Vector2 = _drag_start_size
			match _resizing_corner:
				0:  # top-left
					new_pos = _drag_start_position + delta_resize
					new_size = _drag_start_size - delta_resize
				1:  # top-right
					new_pos = Vector2(_drag_start_position.x, _drag_start_position.y + delta_resize.y)
					new_size = Vector2(_drag_start_size.x + delta_resize.x, _drag_start_size.y - delta_resize.y)
				2:  # bottom-left
					new_pos = Vector2(_drag_start_position.x + delta_resize.x, _drag_start_position.y)
					new_size = Vector2(_drag_start_size.x - delta_resize.x, _drag_start_size.y + delta_resize.y)
				3:  # bottom-right
					new_size = _drag_start_size + delta_resize
			# Clamp to a minimum dimension so the frame doesn't collapse.
			if new_size.x < _MIN_DIM:
				if _resizing_corner == 0 or _resizing_corner == 2:
					new_pos.x -= _MIN_DIM - new_size.x
				new_size.x = _MIN_DIM
			if new_size.y < _MIN_DIM:
				if _resizing_corner == 0 or _resizing_corner == 1:
					new_pos.y -= _MIN_DIM - new_size.y
				new_size.y = _MIN_DIM
			position = new_pos
			size = new_size
			rect_changed.emit(Rect2(position, size))
			get_viewport().set_input_as_handled()
			queue_redraw()


func set_rect(r: Rect2) -> void:
	# External setter that updates position/size without emitting rect_changed.
	# Used when the editor synchronises a frame to a value loaded from disk
	# or set via SpinBox without echoing the signal back.
	position = r.position
	size = r.size
	queue_redraw()


# Returns -1 if no corner was hit, else 0-3 (TL, TR, BL, BR).
func _hit_test_corner(local: Vector2) -> int:
	var hs := handle_size
	if local.x <= hs and local.y <= hs:
		return 0
	if local.x >= size.x - hs and local.y <= hs:
		return 1
	if local.x <= hs and local.y >= size.y - hs:
		return 2
	if local.x >= size.x - hs and local.y >= size.y - hs:
		return 3
	return -1


func _draw() -> void:
	# Body fill (translucent).
	draw_rect(Rect2(Vector2.ZERO, size), fill_color, true)
	# Dashed outline.
	_draw_dashed_outline()
	# Corner handles.
	var hs := handle_size
	var corners: Array = [
		Rect2(Vector2.ZERO, Vector2(hs, hs)),
		Rect2(Vector2(size.x - hs, 0), Vector2(hs, hs)),
		Rect2(Vector2(0, size.y - hs), Vector2(hs, hs)),
		Rect2(Vector2(size.x - hs, size.y - hs), Vector2(hs, hs)),
	]
	for r in corners:
		draw_rect(r, handle_color, true)
	# Centered label.
	if not label_text.is_empty():
		var font := get_theme_default_font()
		if font != null:
			var font_size := 11
			var text_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var pos := Vector2(
				(size.x - text_size.x) * 0.5,
				(size.y + text_size.y) * 0.5,
			)
			draw_string(font, pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)


func _draw_dashed_outline() -> void:
	var dash := 4.0
	var gap := 3.0
	var w := size.x
	var h := size.y
	# Top/bottom edges.
	var x := 0.0
	while x < w:
		var x2 := minf(x + dash, w)
		draw_line(Vector2(x, 0), Vector2(x2, 0), outline_color, 1.0)
		draw_line(Vector2(x, h), Vector2(x2, h), outline_color, 1.0)
		x += dash + gap
	# Left/right edges.
	var y := 0.0
	while y < h:
		var y2 := minf(y + dash, h)
		draw_line(Vector2(0, y), Vector2(0, y2), outline_color, 1.0)
		draw_line(Vector2(w, y), Vector2(w, y2), outline_color, 1.0)
		y += dash + gap
