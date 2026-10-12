extends SceneTree

const WorldData = preload("res://scripts/world.gd")

var output_directory := ""
var game: Node3D


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2 or arguments[0] != "--output-dir":
		push_error("Usage: godot --path . --script tests/visual_test.gd -- --output-dir /existing/directory")
		quit(1)
		return
	output_directory = arguments[1]
	if not DirAccess.dir_exists_absolute(output_directory):
		push_error("Screenshot directory does not exist: " + output_directory)
		quit(1)
		return
	call_deferred("_run")


func capture(filename: String) -> void:
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(output_directory.path_join(filename + ".png"))
	if error != OK:
		push_error("Cannot save screenshot: " + error_string(error))
		quit(1)


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await capture("01-title")
	game.start_game()
	game.player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await capture("02-forest")
	game.open_map()
	await capture("03-map")
	game._set_state(game.State.PLAYING)
	game.player.active = false
	game.toast_time = 0
	game.toast_label.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var viewpoints := [
		{"name": "04-stones", "from": Vector3(-46, 0.1, 11), "to": Vector3(-43, 2, -1)},
		{"name": "05-elder-tree", "from": Vector3(25, 0.1, -35), "to": Vector3(37, 5, -44)},
		{"name": "06-mushrooms", "from": Vector3(28, 0.1, 45), "to": Vector3(40, 2.5, 39)},
	]
	for viewpoint in viewpoints:
		var from: Vector3 = viewpoint.from
		var target: Vector3 = viewpoint.to
		from.y += WorldData.terrain_height(Vector2(from.x, from.z))
		target.y += WorldData.terrain_height(Vector2(target.x, target.z))
		game.player.position = from
		game.player.look_at(Vector3(target.x, from.y, target.z))
		game.player.camera.look_at(target)
		await capture(viewpoint.name)
	game.player.position = WorldData.terrain_point(Vector2(-28, -47.3), 0.1)
	game.player.look_at(WorldData.terrain_point(Vector2(-42, -44), 0.1))
	game.player.camera.look_at(WorldData.terrain_point(Vector2(-42, -44), 2.0))
	await capture("07-hillside")
	root.size = Vector2i(1100, 720)
	game.open_map()
	await capture("08-map-compact")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.queue_free()
	await process_frame
	print("Moonwood: eight visual captures saved to " + output_directory)
	quit()
