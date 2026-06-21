extends Node3D

func _ready() -> void:
	_debris()
	get_tree().create_timer(0.6).timeout.connect(queue_free)

func _debris() -> void:
	for i in 16:
		var d := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * 0.07
		d.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.8, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.9, 1.0)
		mat.emission_energy_multiplier = 4.0
		d.material_override = mat
		add_child(d)

		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1), randf_range(-1, 1)).normalized()
		var t := create_tween()
		t.tween_property(d, "position", dir * randf_range(0.4, 0.9), 0.5) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(d, "scale", Vector3.ZERO, 0.5)
