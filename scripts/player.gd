extends CharacterBody3D

const SPEED             := 7.5
const JUMP_VELOCITY     := 10.0  
const MOUSE_SENS        := 0.002
const GRAVITY_STRENGTH  := 20.0
const SURFACE_SNAP_DIST := 1.8 # max distance to attract to a surface
const GRAVITY_LERP      := 20.0 # how fast gravity direction rotates
const HYSTERESIS        := 0.20 # prevents flipping between two surfaces
const LERP_OFFSET       := Vector3(0.01, 0.01, 0.01) # allows to lerp when new gravity is opposite to the current one

@onready var camera_yaw: Node3D = $CameraYaw
@onready var camera:     Camera3D = $CameraYaw/Camera3D
@onready var shoot_ray:  RayCast3D = $CameraYaw/Camera3D/RayCastShoot
@onready var col_shape:  CollisionShape3D = $CollisionShape3D
@onready var raycasts:   Node3D = $GravityRaycasts

var pitch := 0.0
var gravity_dir := Vector3.DOWN
var target_gravity := Vector3.DOWN
var viewmodel: Node3D
var arm_r: Node3D
var arm_l: Node3D
var muzzle_r: Node3D
var muzzle_l: Node3D
var shoot_from_right := true # alternates right/left

const Projectile := preload("res://scenes/projectile.tscn")
const PROJECTILE_SPEED := 30.0 # lower = bigger visible arc

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_raycasts()
	_build_body()
	_build_arms()

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _build_body() -> void:
	var body := Node3D.new()
	body.name = "BodyModel"
	add_child(body)
	var suit := Color(0.25, 0.35, 0.55)
	var dark := Color(0.15, 0.18, 0.25)
	# Positions are relative to the player origin (camera sits at +0.65)
	_box(body, Vector3(0.45, 0.55, 0.28), Vector3(0,  0.10, 0.35),    suit)  # torso
	_box(body, Vector3(0.42, 0.18, 0.26), Vector3(0, -0.25, 0.35),    dark)  # hips
	_box(body, Vector3(0.16, 0.55, 0.18), Vector3(-0.12, -0.70, 0.35), dark) # leg L
	_box(body, Vector3(0.16, 0.55, 0.18), Vector3( 0.12, -0.70, 0.35), dark) # leg R

func _build_arms() -> void:
	viewmodel = Node3D.new()
	viewmodel.name = "ViewModel"
	camera.add_child(viewmodel)
	var right := _build_arm(1.0)
	var left := _build_arm(-1.0)
	arm_r = right["arm"]; muzzle_r = right["muzzle"]
	arm_l = left["arm"]; muzzle_l = left["muzzle"]

func _build_arm(side: float) -> Dictionary:
	var skin := Color(0.85, 0.65, 0.5)
	var gun := Color(0.12, 0.12, 0.14)
	
	var arm := Node3D.new()
	arm.position = Vector3(0.22 * side, -0.16, -0.25)
	arm.set_meta("rest_pos", arm.position) # remembered for recoil
	viewmodel.add_child(arm)
	
	_box(arm, Vector3(0.08, 0.08, 0.28), Vector3(0, 0, -0.10), skin) # forearm
	_box(arm, Vector3(0.09, 0.09, 0.10), Vector3(0, 0, -0.26), skin) # hand
	
	var pistol := Node3D.new()
	pistol.position = Vector3(0, 0, -0.32)
	arm.add_child(pistol)
	_box(pistol, Vector3(0.07, 0.10, 0.20), Vector3(0,  0.00,  0.00), gun) # body/slide
	_box(pistol, Vector3(0.06, 0.13, 0.07), Vector3(0, -0.10,  0.06), gun) # grip
	
	var muzzle := Marker3D.new()
	muzzle.position = Vector3(0, 0.0, -0.13) # tip of barrel, points -Z
	
	pistol.add_child(muzzle)
	
	return {"arm": arm, "muzzle": muzzle}

func _setup_raycasts() -> void:
	# point each raycast in its local direction, long enough to detect surfaces
	var dirs := {
		"RaycastDown"    : Vector3.DOWN,
		"RaycastUp"      : Vector3.UP,
		"RaycastLeft"    : Vector3.LEFT,
		"RaycastRight"   : Vector3.RIGHT,
		"RaycastForward" : Vector3.FORWARD,
		"RaycastBack"    : Vector3.BACK,
	}
	
	for child in raycasts.get_children():
		if dirs.has(child.name):
			child.target_position = dirs[child.name] * SURFACE_SNAP_DIST
			child.enabled = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_look(event.relative)
	if event.is_action_pressed("shoot"):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _handle_mouse_look(delta: Vector2) -> void:
	#camera_yaw.rotate(camera_yaw.basis.y, -delta.x * MOUSE_SENS)
	rotate(basis.y, -delta.x * MOUSE_SENS)
	
	pitch -= delta.y * MOUSE_SENS
	pitch = clamp(pitch, deg_to_rad(-85), deg_to_rad(85))
	camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	_update_gravity_direction(delta)
	_apply_gravity(delta)
	_handle_movement(delta)
	_handle_jump()
	_handle_shoot()
	_update_collision_orientation()

	move_and_slide()

func _update_gravity_direction(delta: float) -> void:
	var best_normal := -target_gravity
	var best_dist := SURFACE_SNAP_DIST + HYSTERESIS
	
	for ray in raycasts.get_children():
		if ray.is_colliding():
			var hit_normal := ray.get_collision_normal() as Vector3
			var hit_point := ray.get_collision_point() as Vector3
			var dist := global_position.distance_to(hit_point)
			
			if dist < best_dist - HYSTERESIS:
				best_dist = dist
				best_normal = hit_normal
	
	target_gravity = -best_normal
	if gravity_dir != target_gravity:
		var lerp_gravity = gravity_dir + LERP_OFFSET
		gravity_dir = lerp_gravity.lerp(target_gravity, delta * GRAVITY_LERP).normalized()
	
	# Rotate entire player body so local -Y matches gravity_dir
	_align_body_to_gravity()

func _align_body_to_gravity() -> void:
	var target_up := -gravity_dir
	
	# Build a new basis: keep forward as projected current forward
	var current_fwd := transform.basis.z
	var new_right := target_up.cross(current_fwd).normalized()
	
	var new_fwd := new_right.cross(target_up).normalized()
	var new_basis := Basis(new_right, target_up, new_fwd)
	transform.basis = new_basis.orthonormalized()

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
	if Input.is_action_pressed("jump") and is_on_floor_ex():
		velocity += -gravity_dir * JUMP_VELOCITY

func _update_collision_orientation() -> void:
	# Rotate capsule so its long axis aligns with local up
	var local_up := -gravity_dir
	col_shape.global_transform.basis = Basis(
		local_up.cross(transform.basis.z).normalized(),
		local_up,
		transform.basis.z
	).orthonormalized()

func _handle_shoot() -> void:
	if Input.is_action_just_pressed("shoot"):
		if shoot_from_right:
			_fire(muzzle_r, arm_r)
		else:
			_fire(muzzle_l, arm_l)
		shoot_from_right = not shoot_from_right   # flip for next shot

func _fire(muzzle: Marker3D, arm: Node3D) -> void:
	var proj := Projectile.instantiate()
	get_tree().current_scene.add_child(proj)        # add to WORLD, not the player
	proj.global_position = muzzle.global_position
	proj.add_collision_exception_with(self)         # don't hit yourself on spawn

	# Aim along the CAMERA forward (crosshair), not the pistol's slight angle:
	var dir := -camera.global_transform.basis.z
	proj.launch(dir * PROJECTILE_SPEED)

	_recoil(arm)

func _recoil(arm: Node3D) -> void:
	var rest : Vector3 = arm.get_meta("rest_pos")
	var t := create_tween()
	t.tween_property(arm, "position", rest + Vector3(0, 0, 0.05), 0.04)  # kick back
	t.tween_property(arm, "position", rest, 0.12)                        # settle
