extends RigidBody3D

const LIFETIME := 6.0
var _exploded := false

func _ready() -> void:
	gravity_scale = 2.0
	mass = 0.5
	
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	
	_build_visual()
	_build_collision()
	
	body_entered.connect(_on_hit)
	get_tree().create_timer(LIFETIME).timeout.connect(_explode)

func _build_visual() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 0.2, 0.2)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.9, 1.0)
	mat.emission_energy_multiplier = 6.0     # this is what makes it "glow"
	mi.material_override = mat
	add_child(mi)

func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 0.2, 0.2)
	col.shape = box
	add_child(col)

func launch(vel: Vector3) -> void:
	linear_velocity = vel
	angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))

func _on_hit(body: Node) -> void:
	if body.is_in_group("enemies") and body.has_method("take_hit"):
		body.take_hit()
	_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var ex := preload("res://scenes/explosion.tscn").instantiate()
	get_tree().current_scene.add_child(ex)
	ex.global_position = global_position
	queue_free()
