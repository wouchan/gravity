extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 6.0
const MOUSE_SENS = 0.002
const GRAVITY_STRENGTH = 20.0

@onready var camera_yaw: Node3D = $CameraYaw
@onready var camera: Camera3D = $CameraYaw/Camera3D

var pitch = 0.0
var gravity_dir = Vector3.DOWN

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_look(event.relative)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _handle_mouse_look(delta: Vector2) -> void:
	camera_yaw.rotate(transform.basis.y, -delta.x * MOUSE_SENS)
	
	pitch -= delta.y * MOUSE_SENS
	pitch = clamp(pitch, deg_to_rad(-85), deg_to_rad(85))
	camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_movement(delta)
	_handle_jump()

	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor_ex():
		velocity += gravity_dir * GRAVITY_STRENGTH * delta

func is_on_floor_ex() -> bool:
	up_direction = -gravity_dir
	return is_on_floor()

func _handle_movement(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Local movement axes derived from camera yaw and current gravity
	var local_up = -gravity_dir
	var cam_fwd_world = -camera_yaw.global_transform.basis.z
	var move_fwd = (cam_fwd_world - local_up * cam_fwd_world.dot(local_up)).normalized()
	var move_right = -local_up.cross(move_fwd).normalized()
	
	var wish_dir = (move_fwd * -input.y + move_right * input.x).normalized()
	
	# Separate gravity-axis velocity from lateral velocity
	var grav_vel = gravity_dir * velocity.dot(gravity_dir)
	var lateral_vel = velocity - grav_vel
	
	if wish_dir.length() > 0.1:
		lateral_vel = lateral_vel.lerp(wish_dir * SPEED, delta * 12)
	else:
		lateral_vel = lateral_vel.lerp(Vector3.ZERO, delta * 10)
	
	velocity = lateral_vel + grav_vel
	up_direction = -gravity_dir

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor_ex():
		velocity += -gravity_dir * JUMP_VELOCITY
