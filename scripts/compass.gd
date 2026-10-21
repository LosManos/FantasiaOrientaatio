extends Control

const INK := Color("#394d46")
const RED := Color("#bd5346")
const GOLD := Color("#d1ad65")
const TICK := Color("#53665b")


enum Mode { STRIP, MAP, HANDHELD }

var mode := Mode.STRIP
var heading := 0.0
var heading_degrees := 0.0
var rose_rotation_degrees := 0.0
var case_rotation_degrees := 0.0
var font: Font
var dragging := false
var rotating_case := false
var rotating_rose := false
var last_case_pointer_angle := 0.0
var last_rose_pointer_angle := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if mode == Mode.MAP else Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font


func _draw() -> void:
	if font == null:
		return
	if mode == Mode.STRIP:
		_draw_heading_strip()
		return
	var center := size / 2
	var case_angle := case_rotation_degrees if mode == Mode.MAP else 0.0
	var rose_angle := rose_rotation_degrees
	var needle_angle := 0.0 if mode == Mode.MAP else -heading_degrees
	var plate_size := _plate_size()
	var dial_center := _dial_center()
	var radius := minf(plate_size.x * 0.34, plate_size.y * 0.24)
	draw_set_transform(center, deg_to_rad(case_angle), Vector2.ONE)
	draw_rect(Rect2(-plate_size / 2, plate_size), Color(0.70, 0.86, 0.88, 0.14), true)
	draw_rect(Rect2(-plate_size / 2, plate_size), Color(0.76, 0.93, 0.94, 0.82), false, 1.5)
	for tick in range(17):
		var fraction := float(tick) / 16.0
		var y := -plate_size.y / 2 + 8 + fraction * (plate_size.y - 16)
		var major := tick % 4 == 0
		var tick_length := 8.0 if major else 4.0
		draw_line(Vector2(-plate_size.x / 2, y), Vector2(-plate_size.x / 2 + tick_length, y), TICK, 1.0)
		draw_line(Vector2(plate_size.x / 2, y), Vector2(plate_size.x / 2 - tick_length, y), TICK, 1.0)
	var direction_tip := Vector2(0, -plate_size.y / 2 + 14)
	var direction_start := Vector2(0, dial_center.y - radius * 0.72)
	draw_line(direction_start, direction_tip, GOLD, 2.2, true)
	draw_colored_polygon(PackedVector2Array([
		direction_tip,
		direction_tip + Vector2(-5, 11),
		direction_tip + Vector2(5, 11),
	]), GOLD)
	draw_line(Vector2(-plate_size.x * 0.34, dial_center.y - radius * 0.83), Vector2(plate_size.x * 0.34, dial_center.y - radius * 0.83), INK, 1.2)
	draw_arc(dial_center, radius + 4, 0, TAU, 64, Color(0.08, 0.12, 0.11, 0.68), 1.2, true)
	draw_arc(dial_center, radius, 0, TAU, 64, Color(0.82, 0.92, 0.90, 0.55), 1.1, true)
	for tick in range(72):
		var degree := tick * 5.0
		var direction := _direction(rose_angle + degree)
		var major := tick % 4 == 0
		var start := dial_center + direction * (radius - (7.0 if major else 3.5))
		var finish := dial_center + direction * (radius - 1.0)
		draw_line(start, finish, TICK, 1.2 if major else 0.7)
	for degree in range(0, 360, 20):
		var direction := _direction(rose_angle + degree)
		var text := str(degree)
		var font_size := 7
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var text_position := dial_center + direction * (radius - 13) - text_size / 2 + Vector2(0, 2.5)
		draw_string(font, text_position + Vector2(0.7, 0.7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.05, 0.08, 0.07, 0.9))
		draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.96, 0.97, 0.90, 0.96))
	var orienting_direction := _direction(rose_angle)
	var orienting_side := Vector2(-orienting_direction.y, orienting_direction.x) * 2.8
	var orienting_start := dial_center + orienting_direction * (radius * 0.14)
	var orienting_tip := dial_center + orienting_direction * (radius * 0.58)
	var orienting_color := Color("#f5d35e")
	draw_line(orienting_start - orienting_side, orienting_tip - orienting_side, Color(0.04, 0.07, 0.06, 0.9), 5.4)
	draw_line(orienting_start + orienting_side, orienting_tip + orienting_side, Color(0.04, 0.07, 0.06, 0.9), 5.4)
	draw_line(orienting_tip, orienting_tip - orienting_direction * (radius * 0.14) - orienting_side * 2, Color(0.04, 0.07, 0.06, 0.9), 5.4)
	draw_line(orienting_tip, orienting_tip - orienting_direction * (radius * 0.14) + orienting_side * 2, Color(0.04, 0.07, 0.06, 0.9), 5.4)
	draw_line(orienting_start - orienting_side, orienting_tip - orienting_side, orienting_color, 3.0)
	draw_line(orienting_start + orienting_side, orienting_tip + orienting_side, orienting_color, 3.0)
	draw_line(orienting_tip, orienting_tip - orienting_direction * (radius * 0.14) - orienting_side * 2, orienting_color, 3.0)
	draw_line(orienting_tip, orienting_tip - orienting_direction * (radius * 0.14) + orienting_side * 2, orienting_color, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var screen_dial_center := center + dial_center.rotated(deg_to_rad(case_angle))
	var needle_direction := _direction(needle_angle)
	draw_colored_polygon(PackedVector2Array([
		screen_dial_center + needle_direction * (radius * 0.69),
		screen_dial_center + needle_direction.rotated(2.45) * (radius * 0.14),
		screen_dial_center + needle_direction.rotated(-2.45) * (radius * 0.14),
	]), RED)
	draw_colored_polygon(PackedVector2Array([
		screen_dial_center - needle_direction * (radius * 0.54),
		screen_dial_center - needle_direction.rotated(2.45) * (radius * 0.14),
		screen_dial_center - needle_direction.rotated(-2.45) * (radius * 0.14),
	]), Color("#d8d0bb"))
	draw_circle(screen_dial_center, 3.2, INK)
	if mode != Mode.MAP:
		draw_string(font, Vector2(0, size.y - 8), "ALIGN NEEDLE TO ORIENTING ARROW", HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, Color("#f0e8d3"))


func _draw_heading_strip() -> void:
	var center := size.x / 2
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	for index in range(24):
		var degrees := index * 15.0
		var difference := wrapf(degrees - heading, -180, 180)
		if absf(difference) > 60:
			continue
		var x := center + difference * 2.35
		var major := int(fposmod(degrees, 90)) == 0
		draw_line(Vector2(x, 30), Vector2(x, 38 if major else 34), Color("#c2c9b6"), 1)
		if int(fposmod(degrees, 45)) == 0:
			var labels := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
			var text: String = labels[int(fposmod(degrees, 360) / 45)]
			var color := Color("#f4cf81") if text == "N" else Color("#e1e7d9")
			draw_string(font, Vector2(x - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x / 2, 23), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	draw_colored_polygon(PackedVector2Array([Vector2(center - 4, 3), Vector2(center + 4, 3), Vector2(center, 9)]), Color("#f4cf81"))
	var bearing := "%03d degrees" % (int(round(heading)) % 360)
	draw_string(font, Vector2(center - 37, 56), bearing, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f4cf81"))


func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.075, 0.065, 0.86)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style


func _gui_input(event: InputEvent) -> void:
	if mode != Mode.MAP:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				rotating_case = event.shift_pressed
				dragging = not rotating_case
				last_case_pointer_angle = _case_pointer_angle(event.position)
				accept_event()
			else:
				dragging = false
				rotating_case = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			rotating_rose = event.pressed
			if rotating_rose:
				last_rose_pointer_angle = _pointer_angle(event.position)
				accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			case_rotation_degrees = wrapf(case_rotation_degrees - 5.0, 0.0, 360.0)
			queue_redraw()
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			case_rotation_degrees = wrapf(case_rotation_degrees + 5.0, 0.0, 360.0)
			queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion:
		if rotating_case:
			var pointer_angle := _case_pointer_angle(event.position)
			case_rotation_degrees = wrapf(case_rotation_degrees + wrapf(pointer_angle - last_case_pointer_angle, -180.0, 180.0), 0.0, 360.0)
			last_case_pointer_angle = pointer_angle
			queue_redraw()
			accept_event()
		elif dragging:
			var parent_control := get_parent_control()
			position = parent_control.get_local_mouse_position() - size / 2
			position.x = clampf(position.x, 0.0, maxf(0.0, parent_control.size.x - size.x))
			position.y = clampf(position.y, 0.0, maxf(0.0, parent_control.size.y - size.y))
			accept_event()
		elif rotating_rose:
			var pointer_angle := _pointer_angle(event.position)
			rose_rotation_degrees = wrapf(rose_rotation_degrees + wrapf(pointer_angle - last_rose_pointer_angle, -180.0, 180.0), 0.0, 360.0)
			last_rose_pointer_angle = pointer_angle
			queue_redraw()
			accept_event()


func _pointer_angle(point: Vector2) -> float:
	var case_angle := case_rotation_degrees if mode == Mode.MAP else 0.0
	var dial_position := size / 2 + _dial_center().rotated(deg_to_rad(case_angle))
	var offset := point - dial_position
	return rad_to_deg(atan2(offset.x, -offset.y))


func _case_pointer_angle(point: Vector2) -> float:
	var offset := point - size / 2
	return rad_to_deg(atan2(offset.x, -offset.y))


func _direction(degrees: float) -> Vector2:
	return Vector2(sin(deg_to_rad(degrees)), -cos(deg_to_rad(degrees)))


func _plate_size() -> Vector2:
	return Vector2(size.x * 0.60, size.y * 0.78)


func _dial_center() -> Vector2:
	return Vector2(0, _plate_size().y * 0.22)
