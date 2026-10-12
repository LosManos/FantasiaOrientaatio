extends Node3D

const SIZE := 160.0
const CAMP := Vector2(0, 61)
const LAKE := Vector2(44, 3)
const LAKE_RADIUS := 14.0
const TERRAIN_STEP := 2.0
const TERRAIN_EXTENT := 88.0
const CONTOUR_INTERVAL := 2.0
const INDEX_INTERVAL := 10.0
const CONTROLS := [
	{"name": "Whispering Stones", "position": Vector2(-43, -1), "clue": "A circle of stones listens to the western wind."},
	{"name": "The Broken Watchtower", "position": Vector2(-42, -44), "clue": "An old tower stands on the northwestern hill."},
	{"name": "The Elder Tree", "position": Vector2(37, -44), "clue": "In the northeast, a golden tree remembers the stars."},
	{"name": "Giant Mushroom Grove", "position": Vector2(40, 39), "clue": "Southeast of the lake, violet caps shelter a star."},
	{"name": "The Forgotten Arch", "position": Vector2(-35, 36), "clue": "A doorway without walls waits in the southwest."},
]
const PATHS := [
	[Vector2(0, 61), Vector2(0, 40), Vector2(3, 22), Vector2(0, 0)],
	[Vector2(0, 0), Vector2(-23, 5), Vector2(-43, -1)],
	[Vector2(-43, -1), Vector2(-51, -22), Vector2(-42, -44)],
	[Vector2(-42, -44), Vector2(-12, -51), Vector2(12, -49), Vector2(37, -44)],
	[Vector2(0, 0), Vector2(8, -24), Vector2(37, -44)],
	[Vector2(0, 0), Vector2(23, -5), Vector2(30, -19), Vector2(47, -20), Vector2(63, -10), Vector2(64, 21), Vector2(40, 39)],
	[Vector2(40, 39), Vector2(22, 48), Vector2(0, 61)],
	[Vector2(0, 61), Vector2(-22, 54), Vector2(-35, 36)],
	[Vector2(-35, 36), Vector2(-48, 20), Vector2(-43, -1)],
]

@export var paths_enabled := false

var rng := RandomNumberGenerator.new()
var stars: Array[Node3D] = []
var star_material: StandardMaterial3D
var fireflies: MultiMeshInstance3D
var firefly_origins: Array[Vector3] = []
var age := 0.0
var ground_material: StandardMaterial3D
var bark_material: StandardMaterial3D
var rock_material: StandardMaterial3D


static func _land_height(point: Vector2) -> float:
	var height := 1.0
	for hill in [Vector4(-46, -42, 17, 25), Vector4(35, -48, 13, 24), Vector4(-42, 29, 10, 21), Vector4(39, 43, 8, 22), Vector4(-7, -18, 6, 19)]:
		var distance_squared := point.distance_squared_to(Vector2(hill.x, hill.y))
		height += hill.z * exp(-distance_squared / (2.0 * hill.w * hill.w))
	height += 3.0 * exp(-pow((point.x + point.y * 0.3 + 12.0) / 15.0, 2.0))
	return height


static func _vertex_height(point: Vector2) -> float:
	var height := _land_height(point)
	for control in CONTROLS:
		var center: Vector2 = control.position
		height = lerpf(_land_height(center), height, smoothstep(7.0, 13.0, point.distance_to(center)))
	height *= smoothstep(12.0, 26.0, point.distance_to(CAMP))
	height *= smoothstep(LAKE_RADIUS + 3.0, LAKE_RADIUS + 15.0, point.distance_to(LAKE))
	return height


static func terrain_height(point: Vector2) -> float:
	var origin := (point / TERRAIN_STEP).floor() * TERRAIN_STEP
	var fraction := (point - origin) / TERRAIN_STEP
	var southwest := _vertex_height(origin)
	var northeast := _vertex_height(origin + Vector2.ONE * TERRAIN_STEP)
	if fraction.x >= fraction.y:
		var southeast := _vertex_height(origin + Vector2(TERRAIN_STEP, 0))
		return southwest * (1.0 - fraction.x) + southeast * (fraction.x - fraction.y) + northeast * fraction.y
	var northwest := _vertex_height(origin + Vector2(0, TERRAIN_STEP))
	return southwest * (1.0 - fraction.y) + northwest * (fraction.y - fraction.x) + northeast * fraction.x


static func terrain_point(point: Vector2, offset := 0.0) -> Vector3:
	return Vector3(point.x, terrain_height(point) + offset, point.y)


static func terrain_normal(point: Vector2) -> Vector3:
	var east := _vertex_height(point + Vector2.RIGHT) - _vertex_height(point - Vector2.RIGHT)
	var south := _vertex_height(point + Vector2.DOWN) - _vertex_height(point - Vector2.DOWN)
	return Vector3(-east, 2.0, -south).normalized()


static func contour_segments(elevation: float) -> PackedVector2Array:
	var segments := PackedVector2Array()
	var cells := int(SIZE / TERRAIN_STEP)
	for row in range(cells):
		for column in range(cells):
			var origin := Vector2(column, row) * TERRAIN_STEP - Vector2.ONE * SIZE * 0.5
			var corners := [origin, origin + Vector2(TERRAIN_STEP, 0), origin + Vector2.ONE * TERRAIN_STEP, origin + Vector2(0, TERRAIN_STEP)]
			var heights := [_vertex_height(corners[0]), _vertex_height(corners[1]), _vertex_height(corners[2]), _vertex_height(corners[3])]
			for triangle in [[0, 1, 2], [0, 2, 3]]:
				var intersections := PackedVector2Array()
				for edge in range(3):
					var first: int = triangle[edge]
					var second: int = triangle[(edge + 1) % 3]
					if (heights[first] < elevation) != (heights[second] < elevation):
						var fraction: float = (elevation - heights[first]) / (heights[second] - heights[first])
						intersections.append(corners[first].lerp(corners[second], fraction))
				if intersections.size() == 2 and intersections[0].distance_squared_to(intersections[1]) > 0.000001:
					segments.append_array(intersections)
	return segments


func _ready() -> void:
	rng.seed = 71423
	ground_material = material(Color("#304d3d"))
	bark_material = material(Color("#503e32"))
	rock_material = material(Color("#7c9085"))
	star_material = material(Color("#ffe8a1"), Color("#ffc957"))
	_make_environment()
	_make_ground()
	if paths_enabled:
		_make_paths()
	_make_clearings()
	_make_forest()
	_make_landmarks()
	_make_stars()
	_make_fireflies()


func material(color: Color, glow: Color = Color.BLACK) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	if glow != Color.BLACK:
		result.emission_enabled = true
		result.emission = glow
		result.emission_energy_multiplier = 1.5
	return result


func _make_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#314c63")
	sky_material.sky_horizon_color = Color("#ccbb99")
	sky_material.ground_horizon_color = Color("#ccbb99")
	sky_material.ground_bottom_color = Color("#243b38")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b7d7ca")
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("#769e90")
	environment.fog_density = 0.006
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-37, -32, 0)
	sun.light_color = Color("#ffe0a6")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	add_child(sun)


func _make_ground() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := int(TERRAIN_EXTENT * 2.0 / TERRAIN_STEP)
	for row in range(cells):
		for column in range(cells):
			var origin := Vector2(column, row) * TERRAIN_STEP - Vector2.ONE * TERRAIN_EXTENT
			var corners := [origin, origin + Vector2(TERRAIN_STEP, 0), origin + Vector2.ONE * TERRAIN_STEP, origin + Vector2(0, TERRAIN_STEP)]
			for corner in [0, 1, 2, 0, 2, 3]:
				surface.set_normal(terrain_normal(corners[corner]))
				surface.add_vertex(terrain_point(corners[corner]))
	var ground := MeshInstance3D.new()
	ground.name = "Terrain"
	ground.mesh = surface.commit()
	ground.material_override = ground_material
	add_child(ground)
	ground.create_trimesh_collision()
	var shore := material(Color("#9d9771"))
	var water := material(Color("#4d9eaa"))
	water.metallic = 0.3
	water.roughness = 0.2
	cylinder(Vector3(LAKE.x, 0.03, LAKE.y), LAKE_RADIUS + 2, 0.07, shore, 48)
	cylinder(Vector3(LAKE.x, 0.08, LAKE.y), LAKE_RADIUS, 0.08, water, 48)
	var lake_body := StaticBody3D.new()
	lake_body.position = Vector3(LAKE.x, 0.2, LAKE.y)
	add_child(lake_body)
	var lake_collision := CollisionShape3D.new()
	var lake_shape := CylinderShape3D.new()
	lake_shape.radius = LAKE_RADIUS - 0.25
	lake_shape.height = 1.0
	lake_collision.shape = lake_shape
	lake_body.add_child(lake_collision)
	for side in [-1, 1]:
		box(Vector3(side * 83, 3, 0), Vector3(2, 8, 168), ground_material, true)
		box(Vector3(0, 3, side * 83), Vector3(168, 8, 2), ground_material, true)
	var mountain_material := material(Color("#617773"))
	for index in range(30):
		var angle := TAU * index / 30.0
		var center := Vector3(sin(angle) * 108, 7, cos(angle) * 108)
		var mountain := CylinderMesh.new()
		mountain.top_radius = 0.0
		mountain.bottom_radius = rng.randf_range(15, 24)
		mountain.height = rng.randf_range(25, 43)
		mountain.radial_segments = 5
		mesh_node(mountain, center, mountain_material)


func _make_paths() -> void:
	var path_material := material(Color("#8d8560"))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for path in PATHS:
		for index in range(path.size() - 1):
			var start: Vector2 = path[index]
			var end: Vector2 = path[index + 1]
			var perpendicular := (end - start).normalized().orthogonal() * 1.65
			var divisions := ceili(start.distance_to(end) / 0.75)
			for division in range(divisions):
				var first := start.lerp(end, float(division) / divisions)
				var second := start.lerp(end, float(division + 1) / divisions)
				var corners := [first - perpendicular, first + perpendicular, second + perpendicular, second - perpendicular]
				for corner in [0, 1, 2, 0, 2, 3]:
					surface.set_normal(terrain_normal(corners[corner]))
					surface.add_vertex(terrain_point(corners[corner], 0.045))
			cylinder(Vector3(start.x, 0.02, start.y), 1.7, 0.04, path_material, 12)
	var trails := MeshInstance3D.new()
	trails.name = "Trails"
	trails.mesh = surface.commit()
	trails.material_override = path_material
	add_child(trails)


func _make_clearings() -> void:
	cylinder(Vector3(CAMP.x, 0.03, CAMP.y), 7.0, 0.06, material(Color("#8d8560")), 24)
	for control in CONTROLS:
		var point: Vector2 = control.position
		cylinder(Vector3(point.x, 0.035, point.y), 6.5, 0.07, material(Color("#4d6647")), 20)


func is_clear(point: Vector2, padding: float = 0.0) -> bool:
	if point.distance_to(CAMP) < 9.0 + padding or point.distance_to(LAKE) < LAKE_RADIUS + 3.0 + padding:
		return true
	for control in CONTROLS:
		if point.distance_to(control.position) < 8.0 + padding:
			return true
	if not paths_enabled:
		return false
	for path in PATHS:
		for index in range(path.size() - 1):
			var closest := Geometry2D.get_closest_point_to_segment(point, path[index], path[index + 1])
			if point.distance_to(closest) < 3.2 + padding:
				return true
	return false


func _make_forest() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.24
	trunk_mesh.bottom_radius = 0.42
	trunk_mesh.height = 4
	trunk_mesh.radial_segments = 7
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0
	crown_mesh.bottom_radius = 2.8
	crown_mesh.height = 5
	crown_mesh.radial_segments = 7
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var tree_points: Array[Vector2] = []
	for attempt in range(1600):
		var point := Vector2(rng.randf_range(-80, 80), rng.randf_range(-80, 80))
		if is_clear(point):
			continue
		var crowded := false
		for other in tree_points:
			if point.distance_to(other) < 4.3:
				crowded = true
				break
		if crowded:
			continue
		tree_points.append(point)
		var tree_scale := rng.randf_range(0.8, 1.55)
		var basis := Basis.IDENTITY.scaled(Vector3.ONE * tree_scale)
		trunks.append(Transform3D(basis, terrain_point(point, 2 * tree_scale)))
		for tier in range(3):
			var crown_scale := tree_scale * (1.0 - tier * 0.2)
			crowns.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * crown_scale), terrain_point(point, (4.4 + tier * 1.65) * tree_scale)))
		var body := StaticBody3D.new()
		body.position = terrain_point(point, 2 * tree_scale)
		add_child(body)
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.height = 4 * tree_scale
		shape.radius = 0.43 * tree_scale
		collision.shape = shape
		body.add_child(collision)
		if tree_points.size() >= 390:
			break
	multimesh(trunk_mesh, bark_material, trunks)
	multimesh(crown_mesh, material(Color("#244c3b")), crowns)
	var grass_mesh := CylinderMesh.new()
	grass_mesh.top_radius = 0
	grass_mesh.bottom_radius = 0.28
	grass_mesh.height = 0.65
	grass_mesh.radial_segments = 3
	var grass: Array[Transform3D] = []
	for index in range(1800):
		var point := Vector2(rng.randf_range(-79, 79), rng.randf_range(-79, 79))
		if not is_clear(point, -1.4):
			grass.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), terrain_point(point, 0.3)))
	multimesh(grass_mesh, material(Color("#527354")), grass)


func _make_landmarks() -> void:
	var stone := Vector2(-43, -1)
	for index in range(7):
		var angle := index * TAU / 7.0
		var pillar := box(Vector3(stone.x + sin(angle) * 4, 1.5, stone.y + cos(angle) * 4), Vector3(1.2, 3, 0.9), rock_material, true)
		pillar.rotation.z = rng.randf_range(-0.16, 0.16)
		var rune_point := pillar.position + Vector3(0, 0.3, -0.46)
		rune_point.y -= terrain_height(Vector2(rune_point.x, rune_point.z))
		var rune := box(rune_point, Vector3(0.14, 0.8, 0.04), material(Color("#87ebd0"), Color("#4ea995")))
		rune.rotation.z = 0.3
	var tower := Vector2(-42, -44)
	for offset in [Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2)]:
		box(Vector3(tower.x + offset.x, 3.2, tower.y + offset.y), Vector3(1.4, 6.4, 1.4), rock_material, true)
	box(Vector3(tower.x, 5.5, tower.y - 2), Vector3(5.5, 1.3, 1.4), rock_material, true)
	for index in range(5):
		box(Vector3(tower.x - 2.5 + index * 1.25, 6.7, tower.y - 2), Vector3(0.65, 1.2, 1.4), rock_material)
	var tree := Vector2(37, -44)
	cylinder(Vector3(tree.x, 4.3, tree.y), 1.4, 8.6, bark_material, 9, true)
	var leaves := material(Color("#c7aa59"))
	for offset in [Vector3(0, 9, 0), Vector3(-3, 7.7, 0), Vector3(3, 8, 0), Vector3(0, 8, -3)]:
		sphere(Vector3(tree.x, 0, tree.y) + offset, Vector3(4.3, 3.3, 4), leaves)
	var grove := Vector2(40, 39)
	var caps := material(Color("#9c72c1"))
	var stems := material(Color("#c2b7a2"))
	for offset in [Vector2(-3.7, -2), Vector2(2.8, -2.8), Vector2(3.6, 3), Vector2(-3, 3)]:
		var height := rng.randf_range(2.2, 4.3)
		var point := Vector3(grove.x + offset.x, 0, grove.y + offset.y)
		cylinder(point + Vector3(0, height * 0.5, 0), 0.4, height, stems, 9, true)
		sphere(point + Vector3(0, height, 0), Vector3(2.3, 0.85, 2.3), caps)
		for spot in range(4):
			var angle := spot * TAU / 4
			sphere(point + Vector3(sin(angle) * 1.2, height + 0.63, cos(angle) * 1.2), Vector3.ONE * 0.2, star_material)
	var arch := Vector2(-35, 36)
	for side in [-1, 1]:
		box(Vector3(arch.x + side * 2.2, 2.0, arch.y), Vector3(1.2, 4, 1.7), rock_material, true)
	box(Vector3(arch.x, 4.3, arch.y), Vector3(5.6, 1.0, 1.7), rock_material, true)
	cylinder(Vector3(0, 0.3, 62), 2, 0.6, rock_material, 12, true)
	var altar := sphere(Vector3(0, 1.2, 62), Vector3(0.5, 0.7, 0.5), material(Color("#81c6cd"), Color("#54c5c7")))
	altar.name = "CampCrystal"
	for side in [-1, 1]:
		box(Vector3(side * 4.5, 1, 65), Vector3(0.16, 2, 0.16), bark_material)
	var tent := PrismMesh.new()
	tent.size = Vector3(3.8, 2.5, 3.8)
	mesh_node(tent, Vector3(-4.5, 1.25, 65), material(Color("#c38b55")))
	signpost(Vector3(0, 0, 53), "MOONWOOD\nBASE CAMP", 0)
	signpost(Vector3(4.5, 0, 1), "WEST: STONES\nNORTH: ELDER TREE", 0)
	signpost(Vector3(28, 0, 19), "MOONMIRROR LAKE\nDeep water - walk around", -0.6)
	for index in range(CONTROLS.size()):
		var point: Vector2 = CONTROLS[index].position
		signpost(Vector3(point.x - 2, 0, point.y + 4.8), "%02d\n%s" % [index + 1, CONTROLS[index].name], 0)


func signpost(point: Vector3, text: String, angle: float) -> void:
	var root := Node3D.new()
	root.position = point + Vector3.UP * terrain_height(Vector2(point.x, point.z))
	root.rotation.y = angle
	add_child(root)
	cylinder(point + Vector3(0, 0.9, 0), 0.09, 1.8, bark_material, 6)
	var board := BoxMesh.new()
	board.size = Vector3(2.4, 0.85, 0.12)
	var mesh := MeshInstance3D.new()
	mesh.mesh = board
	mesh.material_override = bark_material
	mesh.position.y = 1.8
	root.add_child(mesh)
	var label := Label3D.new()
	label.text = text
	label.position = Vector3(0, 1.8, 0.08)
	label.font_size = 42
	label.pixel_size = 0.008
	label.modulate = Color("#f8e5bc")
	label.outline_size = 3
	root.add_child(label)


func _make_stars() -> void:
	for index in range(CONTROLS.size()):
		var point: Vector2 = CONTROLS[index].position
		# Offset the tree's control to keep the star outside its solid trunk.
		var offset := Vector3(0, 0, 3) if index == 2 else Vector3.ZERO
		var root := Node3D.new()
		root.position = terrain_point(point + Vector2(offset.x, offset.z), 1.5)
		add_child(root)
		var crystal := SphereMesh.new()
		crystal.radius = 0.45
		crystal.height = 1.35
		crystal.radial_segments = 5
		crystal.rings = 2
		var gem := MeshInstance3D.new()
		gem.mesh = crystal
		gem.material_override = star_material
		root.add_child(gem)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.7
		ring.outer_radius = 0.76
		ring.rings = 16
		ring.ring_segments = 6
		var halo := MeshInstance3D.new()
		halo.mesh = ring
		halo.material_override = star_material
		halo.rotation.x = PI / 3
		root.add_child(halo)
		var light := OmniLight3D.new()
		light.light_color = Color("#ffdb85")
		light.light_energy = 1.5
		light.omni_range = 6.5
		root.add_child(light)
		var flag_pole := Vector3(point.x + 1.4, 1, point.y + 1.4) + offset
		cylinder(flag_pole, 0.055, 2, bark_material, 5)
		box(flag_pole + Vector3(0.32, 0.7, 0), Vector3(0.65, 0.45, 0.025), material(Color("#ec9653")))
		box(flag_pole + Vector3(0.32, 0.85, 0.025), Vector3(0.65, 0.15, 0.025), material(Color("#fff3d0")))
		stars.append(root)


func _make_fireflies() -> void:
	var transforms: Array[Transform3D] = []
	for index in range(90):
		var origin := Vector3(rng.randf_range(-65, 65), rng.randf_range(0.9, 3.4), rng.randf_range(-65, 65))
		origin.y += terrain_height(Vector2(origin.x, origin.z))
		firefly_origins.append(origin)
		transforms.append(Transform3D(Basis.IDENTITY, origin))
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	mesh.radial_segments = 4
	mesh.rings = 2
	fireflies = multimesh(mesh, material(Color("#d4f4ab"), Color("#bbef79")), transforms)


func _process(delta: float) -> void:
	age += delta
	for index in range(stars.size()):
		var star := stars[index]
		star.position.y = terrain_height(Vector2(star.position.x, star.position.z)) + 1.5 + sin(age * 1.8 + index) * 0.18
		star.rotation.y += delta * 0.8
	for index in range(firefly_origins.size()):
		var origin := firefly_origins[index]
		var drift := Vector3(sin(age * 0.6 + index) * 0.7, sin(age + index * 0.4) * 0.3, cos(age * 0.5 + index) * 0.7)
		fireflies.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, origin + drift))


func mesh_node(mesh: Mesh, point: Vector3, surface: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = point + Vector3.UP * terrain_height(Vector2(point.x, point.z))
	node.material_override = surface
	add_child(node)
	return node


func box(point: Vector3, size: Vector3, surface: Material, solid := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := mesh_node(mesh, point, surface)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		collider(point, shape)
	return node


func cylinder(point: Vector3, radius: float, height: float, surface: Material, segments := 12, solid := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	var node := mesh_node(mesh, point, surface)
	if solid:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collider(point, shape)
	return node


func sphere(point: Vector3, size: Vector3, surface: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 10
	mesh.rings = 5
	var node := mesh_node(mesh, point, surface)
	node.scale = size
	return node


func collider(point: Vector3, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	body.position = point + Vector3.UP * terrain_height(Vector2(point.x, point.z))
	add_child(body)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)


func multimesh(mesh: Mesh, surface: Material, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for index in range(transforms.size()):
		instances.set_instance_transform(index, transforms[index])
	var node := MultiMeshInstance3D.new()
	node.multimesh = instances
	node.material_override = surface
	add_child(node)
	return node
