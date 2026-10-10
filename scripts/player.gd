extends CharacterBody3D

const WALK_SPEED := 5.0
const RUN_SPEED := 8.5
const MAX_STAMINA := 5.0
const MOUSE_SENSITIVITY := 0.0022
const SPAWN := Vector3(0, 0.1, 58)

var active := false
var stamina := MAX_STAMINA
var sprint_exhausted := false
var camera: Camera3D
var footsteps := 0.0


func _ready() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.65
	camera.fov = 78
	camera.near = 0.08
	camera.far = 240
	add_child(camera)
	camera.current = true
	reset()


func reset() -> void:
	position = SPAWN
	rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	stamina = MAX_STAMINA
	sprint_exhausted = false
	footsteps = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if active and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * MOUSE_SENSITIVITY, -1.35, 1.35)


func _physics_process(delta: float) -> void:
	if not active:
		return
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0
	var movement := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var running := Input.is_action_pressed("sprint") and movement.length() > 0 and not sprint_exhausted
	var speed := RUN_SPEED if running else WALK_SPEED
	stamina = clampf(stamina + (-1.0 if running else 0.7) * delta, 0, MAX_STAMINA)
	if stamina <= 0:
		sprint_exhausted = true
	elif stamina >= MAX_STAMINA * 0.35:
		sprint_exhausted = false
	var direction := global_basis * Vector3(movement.x, 0, movement.y)
	velocity.x = move_toward(velocity.x, direction.x * speed, 28 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 28 * delta)
	move_and_slide()
	if active and movement.length() > 0 and is_on_floor():
		footsteps += delta * (11.0 if running else 7.5)
		camera.position.y = 1.65 + sin(footsteps) * 0.035
	else:
		camera.position.y = lerpf(camera.position.y, 1.65, minf(delta * 10, 1))


func heading_degrees() -> float:
	return fposmod(-rad_to_deg(rotation.y), 360.0)
