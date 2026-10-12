extends Node3D

const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const MapScript = preload("res://scripts/forest_map.gd")
const CompassScript = preload("res://scripts/compass.gd")
const CREAM := Color("#f3ead3")
const GOLD := Color("#f0c981")
const MUTED := Color("#a7bdb0")
const INTERACTION_DISTANCE := 3.0

enum State { MENU, PLAYING, MAP, PAUSED, WON }

var state := State.MENU
var world: WorldScript
var player: PlayerScript
var collected: Array[bool] = [false, false, false, false, false]
var elapsed := 0.0
var steps := 0.0
var previous_position := Vector3.ZERO
var toast_time := 0.0
var hud: Control
var counter_label: Label
var objective_label: Label
var prompt_label: Label
var toast_label: Label
var stamina_bar: ProgressBar
var compass: CompassScript
var handheld_compass: CompassScript
var map_compass: CompassScript
var map_compass_toggle: CheckBox
var handheld_enabled := false
var paper_map: MapScript
var control_list: VBoxContainer
var map_overlay: Control
var menu_overlay: Control
var pause_overlay: Control
var win_overlay: Control
var win_summary: Label
var audio: AudioStreamPlayer
var sound_enabled := true
var paths_enabled := false


func _ready() -> void:
	_register_inputs()
	world = WorldScript.new()
	world.name = "Forest"
	add_child(world)
	player = PlayerScript.new()
	player.name = "Player"
	add_child(player)
	audio = AudioStreamPlayer.new()
	audio.volume_db = -14
	add_child(audio)
	_build_ui()
	get_window().focus_exited.connect(_on_focus_exited)
	_set_state(State.MENU)
	_update_objective()


func _register_inputs() -> void:
	var actions := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT],
		"map": [KEY_M, KEY_TAB],
		"handheld_compass": [KEY_C],
		"interact": [KEY_E],
		"pause": [KEY_ESCAPE],
	}
	for action: String in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		if state == State.PLAYING:
			open_map()
		elif state == State.MAP:
			_set_state(State.PLAYING)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if state == State.PLAYING:
			_set_state(State.PAUSED)
		elif state == State.MAP or state == State.PAUSED:
			_set_state(State.PLAYING)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("handheld_compass") and (state == State.PLAYING or state == State.MAP):
		set_handheld_compass_enabled(not handheld_enabled)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and state == State.PLAYING:
		try_interact()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	compass.heading = player.heading_degrees()
	compass.queue_redraw()
	map_compass.heading_degrees = player.heading_degrees()
	handheld_compass.heading_degrees = player.heading_degrees()
	handheld_compass.rose_rotation_degrees = map_compass.rose_rotation_degrees
	map_compass.queue_redraw()
	handheld_compass.queue_redraw()
	stamina_bar.value = player.stamina / PlayerScript.MAX_STAMINA * 100
	if state == State.PLAYING:
		elapsed += delta
		steps += Vector2(player.position.x, player.position.z).distance_to(Vector2(previous_position.x, previous_position.z))
		var target := nearby_control()
		if target >= 0:
			prompt_label.text = "[ E ]  Gather fallen star  /  " + WorldScript.CONTROLS[target].name
		elif collected.count(true) == collected.size() and at_camp():
			prompt_label.text = "[ E ]  Restore the Moonwood lantern"
		else:
			prompt_label.text = ""
		toast_time = maxf(0, toast_time - delta)
		toast_label.visible = toast_time > 0
	previous_position = player.position


func _on_focus_exited() -> void:
	if state == State.PLAYING:
		_set_state(State.PAUSED)


func _set_state(next: State) -> void:
	state = next
	player.active = state == State.PLAYING
	# Stop immediately, rather than letting movement coast while reading the map.
	if not player.active:
		player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if player.active else Input.MOUSE_MODE_VISIBLE
	menu_overlay.visible = state == State.MENU
	map_overlay.visible = state == State.MAP
	map_compass.visible = state == State.MAP and handheld_enabled
	handheld_compass.visible = state == State.PLAYING and handheld_enabled
	pause_overlay.visible = state == State.PAUSED
	win_overlay.visible = state == State.WON
	hud.visible = state != State.MENU and state != State.WON
	prompt_label.visible = state == State.PLAYING


func start_game() -> void:
	if world.paths_enabled != paths_enabled:
		remove_child(world)
		world.queue_free()
		world = WorldScript.new()
		world.name = "Forest"
		world.paths_enabled = paths_enabled
		add_child(world)
	paper_map.paths_enabled = paths_enabled
	collected.fill(false)
	for star in world.stars:
		star.show()
	player.reset()
	elapsed = 0
	steps = 0
	previous_position = player.position
	_update_objective()
	_set_state(State.PLAYING)
	notify("Start at base camp. Press M to study your map. North is ahead.", 8)


func open_map() -> void:
	paper_map.collected = collected.duplicate()
	paper_map.queue_redraw()
	for child in control_list.get_children():
		control_list.remove_child(child)
		child.queue_free()
	for index in range(WorldScript.CONTROLS.size()):
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 5)
		control_list.add_child(entry)
		var title := "%02d  %s" % [index + 1, WorldScript.CONTROLS[index].name]
		var title_label := label(title, 16, GOLD if not collected[index] else Color("#91c4a6"))
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.add_child(title_label)
		var clue := "FOUND - marked on your map" if collected[index] else str(WorldScript.CONTROLS[index].clue)
		var clue_label := label(clue, 13, MUTED)
		clue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.add_child(clue_label)
	_set_state(State.MAP)
	map_compass_toggle.button_pressed = handheld_enabled


func set_handheld_compass_enabled(enabled: bool) -> void:
	handheld_enabled = enabled
	if is_instance_valid(toast_label):
		toast_label.position.y = -290 if enabled else -185
	if is_instance_valid(map_compass_toggle):
		map_compass_toggle.button_pressed = enabled
	if is_instance_valid(map_compass):
		map_compass.visible = enabled and state == State.MAP
	if is_instance_valid(handheld_compass):
		handheld_compass.visible = enabled and state == State.PLAYING


func nearby_control() -> int:
	var nearest := -1
	var distance := INTERACTION_DISTANCE
	for index in range(world.stars.size()):
		if collected[index]:
			continue
		var star := world.stars[index]
		var horizontal_distance := Vector2(player.position.x, player.position.z).distance_to(Vector2(star.position.x, star.position.z))
		if horizontal_distance > distance:
			continue
		var query := PhysicsRayQueryParameters3D.create(player.camera.global_position, star.global_position)
		query.exclude = [player.get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		distance = horizontal_distance
		nearest = index
	return nearest


func at_camp() -> bool:
	return Vector2(player.position.x, player.position.z).distance_to(WorldScript.CAMP) < 4


func try_interact() -> void:
	if state != State.PLAYING:
		return
	var target := nearby_control()
	if target >= 0:
		collected[target] = true
		world.stars[target].hide()
		_update_objective()
		play_chime(660.0 + collected.count(true) * 70)
		if collected.count(true) == collected.size():
			notify("All five stars found! Navigate back to BASE CAMP and restore the lantern.", 10)
		else:
			notify("Star %d gathered. %s remembers your visit." % [target + 1, WorldScript.CONTROLS[target].name], 6)
	elif collected.count(true) == collected.size() and at_camp():
		win_summary.text = "5 / 5 fallen stars returned\n%s exploring  /  %d metres travelled\n\nThe lantern shines again. The forest remembers you." % [format_time(elapsed), int(steps)]
		play_chime(1046.5)
		_set_state(State.WON)
	else:
		notify("Find a glowing star and stand nearby to gather it. M opens your map.", 4)


func _update_objective() -> void:
	var count := collected.count(true)
	counter_label.text = "%d / 5   STARS GATHERED" % count
	objective_label.text = "Return to base camp. Restore the lantern." if count == 5 else "Read the land. Find the five fallen stars."


func notify(text: String, duration := 5.0) -> void:
	toast_label.text = text
	toast_time = duration
	toast_label.show()


func format_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func play_chime(frequency: float) -> void:
	if not sound_enabled:
		return
	var samples := PackedByteArray()
	var sample_rate := 22050
	var duration := 0.8
	samples.resize(int(sample_rate * duration) * 2)
	for index in range(samples.size() / 2):
		var time := float(index) / sample_rate
		var envelope := minf(time * 35, 1) * exp(-time * 5)
		var wave := sin(TAU * frequency * time) * 0.6 + sin(TAU * frequency * 1.5 * time) * 0.2
		samples.encode_s16(index * 2, int(wave * envelope * 22000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = samples
	audio.stop()
	audio.stream = stream
	audio.play()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_stylebox("normal", "Button", panel_style(Color("#284b3d"), 8))
	theme.set_stylebox("hover", "Button", panel_style(Color("#3a614d"), 8))
	theme.set_stylebox("pressed", "Button", panel_style(Color("#1a382e"), 8))
	var focus_style := panel_style(Color.TRANSPARENT, 8)
	focus_style.border_color = GOLD
	focus_style.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus_style)
	root.theme = theme
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	_build_hud()
	_build_menu(root)
	_build_map(root)
	_build_pause(root)
	_build_win(root)


func _build_hud() -> void:
	var status := PanelContainer.new()
	status.position = Vector2(24, 24)
	status.add_theme_stylebox_override("panel", panel_style(Color(0.035, 0.075, 0.065, 0.88), 10))
	hud.add_child(status)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	status.add_child(column)
	column.add_child(label("M O O N W O O D", 15, GOLD))
	counter_label = label("", 22)
	column.add_child(counter_label)
	objective_label = label("", 13, MUTED)
	column.add_child(objective_label)
	compass = CompassScript.new()
	compass.mode = CompassScript.Mode.STRIP
	compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	compass.position = Vector2(-156, 24)
	compass.size = Vector2(312, 66)
	hud.add_child(compass)
	handheld_compass = CompassScript.new()
	handheld_compass.mode = CompassScript.Mode.HANDHELD
	handheld_compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	handheld_compass.position = Vector2(-96, -202)
	handheld_compass.size = Vector2(192, 192)
	handheld_compass.visible = false
	hud.add_child(handheld_compass)
	var controls := label("M / TAB   Map     |     C   Compass     |     SHIFT   Run     |     ESC   Pause", 13, CREAM)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position = Vector2(24, -36)
	controls.add_theme_stylebox_override("normal", panel_style(Color(0.035, 0.075, 0.065, 0.86), 6, 6))
	hud.add_child(controls)
	var stamina_group := VBoxContainer.new()
	stamina_group.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	stamina_group.position = Vector2(-200, -62)
	stamina_group.custom_minimum_size = Vector2(176, 0)
	hud.add_child(stamina_group)
	stamina_group.add_child(label("BREATH / SPRINT", 11, MUTED))
	stamina_bar = ProgressBar.new()
	stamina_bar.custom_minimum_size = Vector2(176, 6)
	stamina_bar.show_percentage = false
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_bar.add_theme_stylebox_override("background", panel_style(Color("#203b32"), 3, 0))
	stamina_bar.add_theme_stylebox_override("fill", panel_style(Color("#ccb57d"), 3, 0))
	stamina_group.add_child(stamina_bar)
	var crosshair := label("+", 20, Color(0.95, 0.92, 0.8, 0.65))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-6, -14)
	hud.add_child(crosshair)
	prompt_label = label("", 18, GOLD)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-500, -113)
	prompt_label.size = Vector2(1000, 30)
	hud.add_child(prompt_label)
	toast_label = label("", 15, CREAM)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.position = Vector2(-400, -185)
	toast_label.size = Vector2(800, 60)
	var toast_background := panel_style(Color(0.035, 0.075, 0.065, 0.85), 8)
	toast_label.add_theme_stylebox_override("normal", toast_background)
	hud.add_child(toast_label)


func _build_menu(root: Control) -> void:
	menu_overlay = overlay(root)
	var column := modal_column(menu_overlay, 650)
	column.add_child(label("A SMALL ADVENTURE IN A VERY OLD FOREST", 12, GOLD))
	column.add_child(label("Moonwood", 58))
	column.add_child(label("THE FALLEN STAR TRAIL", 17, GOLD))
	column.add_child(spacer(8))
	var story := label("Five stars have fallen into the enchanted forest.\nWithout them, the lantern at base camp will fade.\n\nTake your map and compass. Find the stars at five\nancient landmarks, then bring their light home.", 19)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(story)
	column.add_child(spacer(8))
	column.add_child(label("WASD / ARROWS   Walk       MOUSE   Look\nM / TAB   Paper map       SHIFT   Sprint\nE   Gather / restore       ESC   Pause", 15, MUTED))
	column.add_child(spacer(8))
	column.add_child(label("No enemies. No time limit. Just you, the map, and a little magic.", 13, MUTED))
	var paths_option := CheckBox.new()
	paths_option.text = "Forest paths"
	paths_option.button_pressed = paths_enabled
	paths_option.toggled.connect(func(enabled: bool) -> void: paths_enabled = enabled)
	column.add_child(paths_option)
	column.add_child(button("Enter the forest", start_game))


func _build_map(root: Control) -> void:
	map_overlay = overlay(root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(Color("#152e26"), 12, 16))
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	paper_map = MapScript.new()
	paper_map.custom_minimum_size = Vector2(650, 630)
	row.add_child(paper_map)
	map_compass = CompassScript.new()
	map_compass.mode = CompassScript.Mode.MAP
	map_compass.position = Vector2(40, 220)
	map_compass.size = Vector2(210, 210)
	map_compass.visible = false
	paper_map.add_child(map_compass)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(300, 0)
	column.add_theme_constant_override("separation", 14)
	row.add_child(column)
	column.add_child(label("YOUR FIELD NOTES", 13, GOLD))
	column.add_child(label("The star trail", 28))
	var advice := label("Orient the map with north on your compass. Match trails, water, and landmarks to what you see.", 14, MUTED)
	advice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(advice)
	map_compass_toggle = CheckBox.new()
	map_compass_toggle.text = "Handheld compass  [ C ]"
	map_compass_toggle.button_pressed = handheld_enabled
	map_compass_toggle.toggled.connect(set_handheld_compass_enabled)
	column.add_child(map_compass_toggle)
	var compass_help := label("The clear baseplate has a ruler and direction-of-travel arrow. Drag to move; Shift-drag or use the wheel to turn it. Right-drag the dial so its orienting arrow points north.", 12, MUTED)
	compass_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(compass_help)
	control_list = VBoxContainer.new()
	control_list.add_theme_constant_override("separation", 16)
	column.add_child(control_list)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(space)
	var footer := label("You start at the camp triangle, facing north. The map does not track your location.\n\nMovement pauses while you study the map.", 13, MUTED)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(footer)
	column.add_child(button("Fold map  [ M / TAB ]", func() -> void: _set_state(State.PLAYING)))


func _build_pause(root: Control) -> void:
	pause_overlay = overlay(root)
	var column := modal_column(pause_overlay, 470)
	column.add_child(label("REST A MOMENT", 12, GOLD))
	column.add_child(label("Among the trees", 34))
	column.add_child(label("Your adventure is paused.\n\nWASD / arrows to walk; mouse to look.\nM / Tab for the map; E to gather stars.\nHold Shift to sprint. Follow your compass.\n\nFind all five stars, then return to base camp.", 16, MUTED))
	column.add_child(button("Continue exploring", func() -> void: _set_state(State.PLAYING)))
	column.add_child(button("Study the map", open_map))
	column.add_child(button("Chimes: on / off", func() -> void:
		sound_enabled = not sound_enabled
		notify("Chimes " + ("enabled" if sound_enabled else "muted"))))
	column.add_child(button("Return to title", func() -> void: _set_state(State.MENU)))
	column.add_child(button("Quit game", func() -> void: get_tree().quit()))


func _build_win(root: Control) -> void:
	win_overlay = overlay(root)
	var column := modal_column(win_overlay, 620)
	column.add_child(label("THE FOREST IS ALIGHT", 13, GOLD))
	column.add_child(label("A little magic,\nfound by you.", 45))
	win_summary = label("", 19)
	win_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(win_summary)
	column.add_child(spacer(12))
	column.add_child(button("Walk the star trail again", start_game))
	column.add_child(button("Return to title", func() -> void: _set_state(State.MENU)))


func overlay(root: Control) -> Control:
	var control := Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(control)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.06, 0.05, 0.72)
	control.add_child(shade)
	return control


func modal_column(parent: Control, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(Color(0.045, 0.105, 0.085, 0.96), 16, 32))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = width
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	return column


func panel_style(color: Color, radius: int, margin := 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style


func label(text: String, font_size := 16, color := CREAM) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


func button(text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 48
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.pressed.connect(callback)
	# Gameplay shortcuts also close modals, so buttons must not consume their keys.
	result.focus_mode = Control.FOCUS_NONE
	return result


func spacer(height: float) -> Control:
	var result := Control.new()
	result.custom_minimum_size.y = height
	return result
