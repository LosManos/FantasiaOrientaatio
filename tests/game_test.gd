extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const WorldData = preload("res://scripts/world.gd")
const PlayerData = preload("res://scripts/player.gd")

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	check(game.state == game.State.MENU, "starts at title")
	check(not game.player.active, "movement disabled at title")
	check(game.world.stars.size() == 5, "five stars generated")
	check(not game.world.paths_enabled and not game.paper_map.paths_enabled, "paths disabled by default in forest and map")
	check(not game.world.has_node("Trails"), "path-free forest has no trail mesh")
	check(not game.world.is_clear(Vector2(0, 40)), "disabled paths do not reserve empty forest corridors")
	check(game.world.is_clear(WorldData.CAMP), "path-free mode preserves camp clearing")
	check(game.collected.count(true) == 0, "nothing collected initially")
	check(InputMap.has_action("map") and InputMap.has_action("interact") and InputMap.has_action("handheld_compass"), "inputs registered")
	check(not game.handheld_enabled and not game.handheld_compass.visible, "handheld compass is optional and starts hidden")
	check(game.world.get_node("Terrain").get_child_count() > 0, "terrain has mesh collision")
	check(WorldData.terrain_height(Vector2(-42, -44)) > 10.0, "tower sits on a mapped hill")
	check(is_zero_approx(WorldData.terrain_height(WorldData.CAMP)), "camp stays level")
	check(is_zero_approx(WorldData.terrain_height(WorldData.LAKE)), "lake basin stays level")
	check(game.paper_map.contours.size() >= 5, "map contains multiple elevation contours")
	for contour in game.paper_map.contours:
		var consistent := true
		for point in contour.segments:
			if absf(WorldData.terrain_height(point) - contour.elevation) > 0.001:
				consistent = false
				break
		check(consistent, "contour %d matches terrain elevation" % contour.elevation)

	game.paths_enabled = true
	game.start_game()
	check(game.world.has_node("Trails") and game.paper_map.paths_enabled, "optional paths enabled in forest and map")
	check(game.world.is_clear(Vector2(0, 40)), "enabled paths reserve walkable corridors")
	await physics_frame
	check(game.state == game.State.PLAYING and game.player.active, "starting enables play")
	game.set_handheld_compass_enabled(true)
	check(game.handheld_compass.visible, "enabling handheld compass shows it in the arena")
	check(game.at_camp(), "spawn is at mapped camp")
	check(is_zero_approx(game.player.heading_degrees()), "starts facing north")
	game.player.rotation.y = -PI / 2
	check(is_equal_approx(game.player.heading_degrees(), 90), "clockwise turn points east")
	await process_frame
	await process_frame
	check(is_equal_approx(game.handheld_compass.heading_degrees, 90), "handheld needle receives player heading")
	game.player.rotation.y = PI / 2
	check(is_equal_approx(game.player.heading_degrees(), 270), "counterclockwise turn points west")
	game.player.rotation.y = 0
	game.try_interact()
	check(game.collected.count(true) == 0 and game.state == game.State.PLAYING, "cannot finish without stars")
	await exercise_movement(game)
	game.player.reset()

	game.open_map()
	check(game.state == game.State.MAP and not game.player.active, "map suspends movement")
	check(game.map_compass.visible and not game.handheld_compass.visible, "enabled compass moves to the map view")
	var wheel_turn := InputEventMouseButton.new()
	wheel_turn.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_turn.pressed = true
	game.map_compass._gui_input(wheel_turn)
	check(is_equal_approx(game.map_compass.case_rotation_degrees, 5), "mouse wheel rotates the whole map baseplate")
	game.map_compass.case_rotation_degrees = 35
	game.map_compass.rose_rotation_degrees = 325
	check(is_equal_approx(game.map_compass.case_rotation_degrees, 35) and is_equal_approx(game.map_compass.rose_rotation_degrees, 325), "map compass stores separate baseplate and rose rotations")
	game.map_compass.case_rotation_degrees = 0
	var rotate_press := InputEventMouseButton.new()
	rotate_press.button_index = MOUSE_BUTTON_LEFT
	rotate_press.pressed = true
	rotate_press.shift_pressed = true
	rotate_press.position = game.map_compass.size / 2 + Vector2(30, 0)
	game.map_compass._gui_input(rotate_press)
	var rotate_motion := InputEventMouseMotion.new()
	rotate_motion.position = game.map_compass.size / 2 + Vector2(0, 30)
	game.map_compass._gui_input(rotate_motion)
	check(is_equal_approx(game.map_compass.case_rotation_degrees, 90), "shift-drag rotates the whole map compass")
	var rotate_release := InputEventMouseButton.new()
	rotate_release.button_index = MOUSE_BUTTON_LEFT
	game.map_compass._gui_input(rotate_release)
	game.map_compass.case_rotation_degrees = 0
	check(game.paper_map.collected.size() == 5, "map has five control statuses")
	check(game.control_list.get_child_count() == 5, "map lists five control clues")
	var previous_elapsed: float = game.elapsed
	var previous_location: Vector3 = game.player.position
	await create_timer(0.1).timeout
	check(is_equal_approx(game.elapsed, previous_elapsed), "exploration timer pauses on map")
	check(game.player.position.distance_to(previous_location) < 0.15, "reading map prevents locomotion")
	game.try_interact()
	check(game.collected.count(true) == 0, "map cannot gather stars")
	game._set_state(game.State.PLAYING)
	await process_frame
	await process_frame
	check(game.handheld_compass.visible and is_equal_approx(game.handheld_compass.rose_rotation_degrees, 325), "map ring orientation carries into the handheld forest compass")

	for index in range(game.world.stars.size()):
		var star: Node3D = game.world.stars[index]
		game.player.position = WorldData.terrain_point(Vector2(star.position.x, star.position.z + 2.1), 0.1)
		game.player.velocity = Vector3.ZERO
		await physics_frame
		await physics_frame
		check(game.nearby_control() == index, "control %d reachable with clear sight" % (index + 1))
		game.try_interact()
		check(game.collected[index], "control %d collected" % (index + 1))
		check(not star.visible, "collected star is hidden")
		var count: int = game.collected.count(true)
		game.try_interact()
		check(game.collected.count(true) == count, "cannot gather the same star twice")
	check(game.collected.count(true) == 5, "all stars gathered")
	check(game.state == game.State.PLAYING, "must return to camp to win")

	game.open_map()
	check(game.paper_map.collected.count(true) == 5, "map checks off all gathered stars")
	game._set_state(game.State.PLAYING)
	game.player.reset()
	await physics_frame
	await physics_frame
	game.try_interact()
	check(game.state == game.State.WON, "returning stars to camp wins")
	check(not game.player.active and game.win_overlay.visible, "victory releases controls and shows summary")
	check(game.win_summary.text.contains("5 / 5"), "victory summary reports all stars")

	game.paths_enabled = false
	game.start_game()
	check(not game.world.has_node("Trails") and not game.paper_map.paths_enabled, "replay can disable paths in forest and map")
	check(game.collected.count(true) == 0, "replay clears collected controls")
	check(game.elapsed == 0 and game.steps == 0, "replay resets statistics")
	for star in game.world.stars:
		check(star.visible, "replay restores each star")
	check(is_equal_approx(game.player.stamina, PlayerData.MAX_STAMINA), "replay restores breath")
	game._on_focus_exited()
	check(game.state == game.State.PAUSED and not game.player.active, "focus loss pauses game")
	check(game.format_time(125) == "2:05", "timer formatting")
	check(WorldData.PATHS.size() > 0, "trails shared with map")
	game.open_map()
	await process_frame
	check(game.paper_map.map_point(WorldData.CAMP).y > game.paper_map.map_rect.get_center().y, "camp is in map's south")
	check(game.paper_map.map_point(WorldData.CONTROLS[1].position).y < game.paper_map.map_rect.get_center().y, "tower is in map's north")
	check(game.audio.stream != null and game.audio.stream.get_length() > 0.7, "collection synthesizes an audible chime")
	# Let the audio server release the short playbacks before shutting down the tree.
	await create_timer(1.0).timeout
	game.audio.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.queue_free()
	await process_frame
	print("Moonwood: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func exercise_movement(game: Node3D) -> void:
	var player: CharacterBody3D = game.player
	for frame in range(8):
		await physics_frame
	check(player.is_on_floor(), "player settles onto the ground at spawn")
	check(absf(player.position.y) < 0.1, "spawn is outside the camp altar collider")
	var initial_z := player.position.z
	Input.action_press("move_forward")
	for frame in range(30):
		await physics_frame
	Input.action_release("move_forward")
	check(initial_z - player.position.z > 1.5, "forward input moves north along trail")
	check(initial_z - player.position.z < 3.0, "walking respects configured speed")

	player.reset()
	for frame in range(8):
		await physics_frame
	initial_z = player.position.z
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for frame in range(30):
		await physics_frame
	check(initial_z - player.position.z > 3.0, "sprint is faster than walking")
	check(player.stamina < PlayerData.MAX_STAMINA, "sprinting consumes breath")
	player.stamina = 0.04
	for frame in range(10):
		await physics_frame
	check(player.sprint_exhausted, "empty breath triggers recovery instead of sprint stutter")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var low_stamina: float = player.stamina
	for frame in range(20):
		await physics_frame
	check(player.stamina > low_stamina, "resting restores breath")

	player.position = WorldData.terrain_point(Vector2(0, 36), 0.1)
	player.velocity = Vector3.ZERO
	for frame in range(8):
		await physics_frame
	var initial_height := player.position.y
	initial_z = player.position.z
	Input.action_press("move_forward")
	for frame in range(60):
		await physics_frame
	Input.action_release("move_forward")
	check(initial_z - player.position.z > 3.5, "player can walk uphill along the trail")
	check(player.position.y > initial_height + 0.2, "walking uphill gains elevation")
	check(absf(player.position.y - WorldData.terrain_height(Vector2(player.position.x, player.position.z))) < 0.15, "player follows the mapped terrain surface")

	player.position = Vector3(WorldData.LAKE.x, 0.1, WorldData.LAKE.y + WorldData.LAKE_RADIUS + 2)
	player.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	for frame in range(55):
		await physics_frame
	Input.action_release("move_forward")
	var lake_distance := Vector2(player.position.x, player.position.z).distance_to(WorldData.LAKE)
	check(lake_distance >= WorldData.LAKE_RADIUS - 0.3, "lake collision prevents walking into water")
	player.position = WorldData.terrain_point(Vector2(0, -80), 0.1)
	player.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	for frame in range(55):
		await physics_frame
	Input.action_release("move_forward")
	check(player.position.z > -82, "forest boundary prevents leaving the world")
