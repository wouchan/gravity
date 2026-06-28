extends CharacterBody3D

const MOVE_SPEED        := 2.5      # slow approach
const GRAVITY           := 20.0
const SIGHT_RANGE       := 35.0
const STOP_DISTANCE     := 5.0      # stop walking but keep shooting inside this
const SHOOT_INTERVAL    := 1.3
const ENEMY_PROJ_SPEED  := 20.0
const TURN_LERP         := 8.0
const WALK_CADENCE      := 9.0
const LEG_SWING         := 0.6      # radians (~34°)

const EnemyProjectile := preload("res://scenes/enemy_projectile.tscn")

var player : Node3D
var _dead := false
var _shoot_timer := 0.0
var _walk_phase := 0.0

var _col   : CollisionShape3D
var _model : Node3D
var _lower : Node3D
var _upper : Node3D
var _arms  : Node3D
var _legL_pivot : Node3D
var _legR_pivot : Node3D
var _muzzle : Marker3D

signal died

# ── Setup ─────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("enemies")
	_build_collision()
	_build_model()
	player = get_tree().get_first_node_in_group("player")
	_shoot_timer = randf() * SHOOT_INTERVAL    # desync multiple enemies

# ── Per-frame brain ───────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _dead:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return

	# World gravity (enemies always obey normal gravity)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	var moving := false

	if _can_see_player():
		var to_player := player.global_position - global_position
		var flat := Vector3(to_player.x, 0, to_player.z)
		var dist := flat.length()

		_aim_upper_body(delta)             # chest + rifle track the player

		if dist > STOP_DISTANCE:
			var dir := flat.normalized()
			velocity.x = dir.x * MOVE_SPEED
			velocity.z = dir.z * MOVE_SPEED
			_face_lower_body(dir, delta)   # legs face where it walks
			moving = true
		else:
			velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED)
			velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED)

		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			_shoot_timer = SHOOT_INTERVAL
			_fire()
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED)
		velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED)
		_arms.rotation.x = lerp_angle(_arms.rotation.x, 0.0, delta * TURN_LERP)

	_animate_legs(delta, moving)
	move_and_slide()

# ── Perception ────────────────────────────────────────────────────────
func _can_see_player() -> bool:
	var to := player.global_position - global_position
	if to.length() > SIGHT_RANGE:
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.6, player.global_position)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and hit.collider == player

# ── Aiming / facing ───────────────────────────────────────────────────
func _face_lower_body(dir: Vector3, delta: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	_lower.rotation.y = lerp_angle(_lower.rotation.y, target_yaw, delta * TURN_LERP)

func _aim_upper_body(delta: float) -> void:
	var flat := player.global_position - _upper.global_position
	flat.y = 0
	var target_yaw := atan2(-flat.x, -flat.z)
	_upper.rotation.y = lerp_angle(_upper.rotation.y, target_yaw, delta * TURN_LERP)

	# Pitch the arms+rifle up/down toward the player's elevation
	var d := player.global_position - _arms.global_position
	var horiz := Vector2(d.x, d.z).length()
	var target_pitch := atan2(d.y, horiz)
	_arms.rotation.x = lerp_angle(_arms.rotation.x, target_pitch, delta * TURN_LERP)

func _animate_legs(delta: float, moving: bool) -> void:
	if moving:
		_walk_phase += delta * WALK_CADENCE
		var swing := sin(_walk_phase) * LEG_SWING
		_legL_pivot.rotation.x =  swing
		_legR_pivot.rotation.x = -swing
	else:
		_legL_pivot.rotation.x = lerp_angle(_legL_pivot.rotation.x, 0.0, delta * 10.0)
		_legR_pivot.rotation.x = lerp_angle(_legR_pivot.rotation.x, 0.0, delta * 10.0)

# ── Shooting ──────────────────────────────────────────────────────────
func _fire() -> void:
	var proj := EnemyProjectile.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = _muzzle.global_position
	proj.add_collision_exception_with(self)
	var dir := (player.global_position - _muzzle.global_position).normalized()
	proj.launch(dir * ENEMY_PROJ_SPEED)

# ── Construction ──────────────────────────────────────────────────────
func _build_collision() -> void:
	_col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	_col.shape = cap
	add_child(_col)

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

func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	_build_lower()
	_build_upper()

func _build_lower() -> void:
	_lower = Node3D.new()
	_lower.name = "LowerBody"
	_model.add_child(_lower)
	var limb := Color(0.30, 0.10, 0.10)
	_box(_lower, Vector3(0.42, 0.18, 0.26), Vector3(0, -0.10, 0), limb)  # hips
	_legL_pivot = _make_leg(-0.12, limb)
	_legR_pivot = _make_leg( 0.12, limb)

func _make_leg(x: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, -0.25, 0)          # hip joint = swing pivot
	_lower.add_child(pivot)
	_box(pivot, Vector3(0.16, 0.50, 0.18), Vector3(0, -0.28, 0), color)  # leg hangs below
	return pivot

func _build_upper() -> void:
	_upper = Node3D.new()
	_upper.name = "UpperBody"
	_model.add_child(_upper)
	_box(_upper, Vector3(0.45, 0.50, 0.28), Vector3(0, 0.28, 0), Color(0.65, 0.20, 0.20)) # chest
	_box(_upper, Vector3(0.30, 0.30, 0.28), Vector3(0, 0.70, 0), Color(0.80, 0.55, 0.45)) # head

	_arms = Node3D.new()
	_arms.name = "Arms"
	_arms.position = Vector3(0, 0.40, 0)           # shoulder pivot (yaw with chest, pitch to aim)
	_upper.add_child(_arms)
	var limb := Color(0.30, 0.10, 0.10)
	var gun  := Color(0.12, 0.12, 0.14)
	_box(_arms, Vector3(0.10, 0.10, 0.30), Vector3(-0.16, 0.0, -0.18), limb)  # arm L
	_box(_arms, Vector3(0.10, 0.10, 0.30), Vector3( 0.16, 0.0, -0.18), limb)  # arm R

	var rifle := Node3D.new()
	rifle.position = Vector3(0, -0.02, -0.30)
	_arms.add_child(rifle)
	_box(rifle, Vector3(0.08, 0.10, 0.45), Vector3(0,  0.00,  0.00), gun)  # body
	_box(rifle, Vector3(0.05, 0.05, 0.30), Vector3(0,  0.04, -0.30), gun)  # barrel
	_box(rifle, Vector3(0.06, 0.14, 0.10), Vector3(0, -0.10,  0.14), gun)  # magazine
	_muzzle = Marker3D.new()
	_muzzle.position = Vector3(0, 0.04, -0.48)     # barrel tip
	rifle.add_child(_muzzle)

# ── Death (from the player's cube) ────────────────────────────────────
func take_hit() -> void:
	if _dead:
		return
	_dead = true
	died.emit()
	set_physics_process(false)
	_col.set_deferred("disabled", true)
	_glow_and_vanish()

func _glow_and_vanish() -> void:
	var glow := Color(0.7, 0.9, 1.0)
	var meshes : Array[MeshInstance3D] = []
	_collect_meshes(_model, meshes)
	var t := create_tween()
	t.set_parallel(true)
	for mi in meshes:
		var mat := mi.material_override as StandardMaterial3D
		if mat:
			mat.emission_enabled = true
			mat.emission = glow
			t.tween_property(mat, "emission_energy_multiplier", 10.0, 0.12)
	t.set_parallel(false)
	t.tween_property(_model, "scale", Vector3.ZERO, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)

func _collect_meshes(node: Node, arr: Array[MeshInstance3D]) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			arr.append(c)
		_collect_meshes(c, arr)
