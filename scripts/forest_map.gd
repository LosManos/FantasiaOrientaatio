extends Control

const WorldData = preload("res://scripts/world.gd")
const INK := Color("#394d46")
const PAPER := Color("#eddfba")
const PURPLE := Color("#795d8a")
const CONTOUR_INK := Color("#9b613b")

var collected: Array[bool] = [false, false, false, false, false]
var map_rect := Rect2()
var font: Font
var contours: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	for elevation in range(2, 32, int(WorldData.CONTOUR_INTERVAL)):
		var segments := WorldData.contour_segments(float(elevation))
		if not segments.is_empty():
			contours.append({"elevation": elevation, "segments": segments})
	resized.connect(queue_redraw)


func map_point(point: Vector2) -> Vector2:
	return map_rect.position + (point + Vector2.ONE * 80) / 160 * map_rect.size


func _draw() -> void:
	if font == null:
		return
	var side := minf(size.x - 60, size.y - 110)
	map_rect = Rect2(Vector2((size.x - side) / 2, 54), Vector2.ONE * side)
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	draw_rect(Rect2(Vector2(10, 10), size - Vector2(20, 20)), Color("#bba982"), false, 1)
	_text(Vector2(30, 36), "MOONWOOD", 23, INK)
	_text(Vector2(size.x - 183, 34), "FIELD MAP / 01", 12, INK)
	draw_rect(map_rect, Color("#e0d4ab"))
	for index in range(9):
		var fraction := index / 8.0
		var x := map_rect.position.x + fraction * side
		var y := map_rect.position.y + fraction * side
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), Color(0.35, 0.4, 0.29, 0.13))
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), Color(0.35, 0.4, 0.29, 0.13))
	var rng := RandomNumberGenerator.new()
	rng.seed = 118
	for index in range(190):
		var point := Vector2(rng.randf_range(-76, 76), rng.randf_range(-76, 76))
		if point.distance_to(WorldData.LAKE) < 18 or point.distance_to(WorldData.CAMP) < 9:
			continue
		var p := map_point(point)
		var tree_size := rng.randf_range(2.5, 4.5)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -tree_size), p + Vector2(-tree_size * 0.7, tree_size), p + Vector2(tree_size * 0.7, tree_size)]), Color(0.28, 0.43, 0.32, 0.35))
	for contour in contours:
		var points := PackedVector2Array()
		for point in contour.segments:
			points.append(map_point(point))
		var is_index: bool = contour.elevation % int(WorldData.INDEX_INTERVAL) == 0
		draw_multiline(points, CONTOUR_INK, 1.8 if is_index else 0.9, true)
	for path in WorldData.PATHS:
		var points := PackedVector2Array()
		for point in path:
			points.append(map_point(point))
		draw_polyline(points, Color("#c6ac79"), 6, true)
		draw_polyline(points, Color("#957c56"), 1.5, true)
	var lake := map_point(WorldData.LAKE)
	draw_circle(lake, WorldData.LAKE_RADIUS / 160 * side, Color("#86b9bd"))
	draw_arc(lake, WorldData.LAKE_RADIUS / 160 * side, 0, TAU, 40, Color("#527f86"), 1.5, true)
	_text(lake + Vector2(-24, -3), "Moonmirror", 10, Color("#355c69"))
	_text(lake + Vector2(-11, 10), "Lake", 10, Color("#355c69"))
	var camp := map_point(WorldData.CAMP)
	draw_colored_polygon(PackedVector2Array([camp + Vector2(0, -9), camp + Vector2(-9, 7), camp + Vector2(9, 7)]), Color("#a6663f"))
	_text(camp + Vector2(14, 5), "BASE CAMP", 11, INK)
	_text(camp + Vector2(-22, 24), "START / FINISH", 9, INK)
	for index in range(WorldData.CONTROLS.size()):
		var point := map_point(WorldData.CONTROLS[index].position)
		var color := Color("#478263") if collected[index] else PURPLE
		draw_circle(point, 15, PAPER)
		draw_arc(point, 15, 0, TAU, 32, color, 2.3, true)
		var number := str(index + 1)
		_text(point + Vector2(-4, 5), number, 15, color)
		if collected[index]:
			draw_line(point + Vector2(8, -13), point + Vector2(12, -9), color, 2)
			draw_line(point + Vector2(12, -9), point + Vector2(19, -18), color, 2)
		var label_offset := Vector2(19, 5)
		if index == 2 or index == 3:
			label_offset = Vector2(-92, -22)
		var short_names := ["STONES", "WATCHTOWER", "ELDER TREE", "MUSHROOMS", "OLD ARCH"]
		_text(point + label_offset, short_names[index], 10, INK)
	for contour in contours:
		if contour.elevation % int(WorldData.INDEX_INTERVAL) != 0:
			continue
		var segments: PackedVector2Array = contour.segments
		var label_point := map_point(segments[segments.size() / 2])
		draw_rect(Rect2(label_point - Vector2(2, 11), Vector2(30, 14)), PAPER)
		_text(label_point, "%d m" % contour.elevation, 10, CONTOUR_INK)
	var north := map_rect.position + Vector2(side - 24, 32)
	draw_line(north + Vector2(0, 16), north + Vector2(0, -12), INK, 2, true)
	draw_colored_polygon(PackedVector2Array([north + Vector2(0, -18), north + Vector2(-5, -7), north + Vector2(5, -7)]), INK)
	_text(north + Vector2(-5, -24), "N", 13, INK)
	var scale_start := map_rect.position + Vector2(14, side - 18)
	var scale_length := side / 8
	draw_line(scale_start, scale_start + Vector2(scale_length, 0), INK, 2)
	for x in [0.0, scale_length]:
		draw_line(scale_start + Vector2(x, -4), scale_start + Vector2(x, 4), INK, 1)
	_text(scale_start + Vector2(0, -9), "20 metres", 10, INK)
	draw_rect(map_rect, Color("#9e9877"), false, 1)
	_text(Vector2(30, size.y - 44), "CONTOURS 2 m / INDEX 10 m", 11, CONTOUR_INK)
	_text(Vector2(30, size.y - 26), "NORTH IS UP  /  20 m GRID  /  NO LIVE POSITION MARKER", 11, INK)


func _text(point: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
