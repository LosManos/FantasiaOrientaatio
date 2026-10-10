extends Control

var heading := 0.0
var font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font


func _draw() -> void:
	if font == null:
		return
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
	# The label is separate from the ticks so a bearing is readable between cardinal directions.
	draw_string(font, Vector2(center - 37, 56), bearing, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f4cf81"))


func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.075, 0.065, 0.86)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style
