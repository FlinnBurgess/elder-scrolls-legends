class_name ErrorReportPopover
extends Control

signal report_submitted(comment: String)
signal dismissed

const MAX_COMMENT_LENGTH := 500

var _context_label: Label
var _comment_input: LineEdit
var _submit_button: Button
var _status_label: Label
var _content_panel: PanelContainer
var _is_submitting := false


func _ready() -> void:
	name = "ErrorReportPopover"
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	z_index = 470
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Semi-transparent background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_bg_input)
	add_child(bg)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Content panel
	_content_panel = PanelContainer.new()
	_content_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_content_panel.custom_minimum_size = Vector2(630, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.97)
	style.border_color = Color(0.35, 0.36, 0.42, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(0)
	_content_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_content_panel)

	# Margin
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	_content_panel.add_child(margin)

	# Content VBox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	# Context label
	_context_label = Label.new()
	_context_label.add_theme_font_size_override("font_size", 23)
	_context_label.add_theme_color_override("font_color", Color(0.85, 0.83, 0.78, 1.0))
	_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_context_label)

	# Comment input
	_comment_input = LineEdit.new()
	_comment_input.placeholder_text = "Describe the issue..."
	_comment_input.max_length = MAX_COMMENT_LENGTH
	_comment_input.custom_minimum_size = Vector2(570, 54)
	_comment_input.add_theme_font_size_override("font_size", 23)
	_comment_input.text_submitted.connect(_on_text_submitted)
	vbox.add_child(_comment_input)

	# Submit button
	_submit_button = Button.new()
	_submit_button.text = "Submit Report"
	_submit_button.custom_minimum_size = Vector2(0, 54)
	_submit_button.add_theme_font_size_override("font_size", 23)
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.25, 0.14, 0.13, 0.98)
	btn_normal.set_corner_radius_all(8)
	btn_normal.set_content_margin_all(12)
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.35, 0.2, 0.18, 0.98)
	btn_hover.set_corner_radius_all(8)
	btn_hover.set_content_margin_all(12)
	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.45, 0.25, 0.22, 0.98)
	btn_pressed.set_corner_radius_all(8)
	btn_pressed.set_content_margin_all(12)
	_submit_button.add_theme_stylebox_override("normal", btn_normal)
	_submit_button.add_theme_stylebox_override("hover", btn_hover)
	_submit_button.add_theme_stylebox_override("pressed", btn_pressed)
	_submit_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_submit_button.add_theme_color_override("font_color", Color(0.98, 0.93, 0.9, 1.0))
	_submit_button.pressed.connect(_on_submit_pressed)
	vbox.add_child(_submit_button)

	# Status label (hidden until submission)
	_status_label = Label.new()
	_status_label.text = "Report created"
	_status_label.add_theme_font_size_override("font_size", 21)
	_status_label.add_theme_color_override("font_color", Color(0.56, 0.94, 0.56, 1.0))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.visible = false
	vbox.add_child(_status_label)

	# Grab focus on the input after a frame so it's ready
	_comment_input.call_deferred("grab_focus")


func show_report(context_label: String) -> void:
	_context_label.text = "Reporting: %s" % context_label
	visible = true


func _on_bg_input(event: InputEvent) -> void:
	if _is_submitting:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dismissed.emit()
		queue_free()


func _on_text_submitted(_text: String) -> void:
	_try_submit()


func _on_submit_pressed() -> void:
	_try_submit()


func _try_submit() -> void:
	if _is_submitting:
		return
	var comment := _comment_input.text.strip_edges()
	if comment.is_empty():
		# Flash the input to indicate it's required
		_comment_input.placeholder_text = "Comment is required"
		return
	_is_submitting = true
	_comment_input.editable = false
	_submit_button.disabled = true
	_status_label.visible = true
	report_submitted.emit(comment)
	# Close after brief pause
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(_on_close_timeout)


func _on_close_timeout() -> void:
	queue_free()
