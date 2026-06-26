extends RigidBody3D

var _done := false

func _ready() -> void:
	gravity_scale = 0.0          # flies straight at the player — dodgeable
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	_build_visual()
	_build_collision()
	body_entered.connect(_on_hit)
	get_tree().create_timer(5.0).timeout.connect(_vanish)

func _build_visual() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.18, 0.18, 0.18)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2)
	mat.emission_energy_multiplier = 6.0
	mi.material_override = mat
	add_child(mi)

func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.18, 0.18, 0.18)
	col.shape = box
	add_child(col)

func launch(vel: Vector3) -> void:
	linear_velocity = vel

func _on_hit(body: Node) -> void:
	if _done:
		return
	if body.is_in_group("player") and body.has_method("hit"):
		body.hit()
	_vanish()

func _vanish() -> void:
	if _done:
		return
	_done = true
	queue_free()
