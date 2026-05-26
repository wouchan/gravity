extends Node3D

# Room dimensions
const W := 16.0 # width
const H := 8.0  # height
const D := 20.0 # depth

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_build_room()
	_add_lights()

func _build_room() -> void:
	var surfaces := [
		# [size,               position,                 name    ]
		[Vector3(W,   0.3, D), Vector3(0, -H/2,   0),   "Floor"  ],
		[Vector3(W,   0.3, D), Vector3(0,  H/2,   0),   "Ceiling"],
		[Vector3(0.3, H,   D), Vector3(-W/2, 0,   0),   "WallL"  ],
		[Vector3(0.3, H,   D), Vector3( W/2, 0,   0),   "WallR"  ],
		[Vector3(W,   H,  0.3),Vector3(0,    0, -D/2),  "WallFwd"],
		[Vector3(W,   H,  0.3),Vector3(0,    0,  D/2),  "WallBck"],
	]
	
	for s in surfaces:
		var box := CSGBox3D.new()
		box.size = s[0]
		box.position = s[1]
		box.name = s[2]
		box.use_collision = true
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _surface_color(s[2])
		box.material = mat
		
		add_child(box)

func _surface_color(surface_name: String) -> Color:
	match surface_name:
		"Floor"   : return Color(0.35, 0.55, 0.35)
		"Ceiling" : return Color(0.45, 0.45, 0.65)
		"WallL"   : return Color(0.60, 0.40, 0.35)
		"WallR"   : return Color(0.60, 0.40, 0.35)
		"WallFwd" : return Color(0.55, 0.50, 0.40)
		"WallBck" : return Color(0.55, 0.50, 0.40)
	return Color(0.5, 0.5, 0.5)

func _add_lights() -> void:
	var light := OmniLight3D.new()
	light.position = Vector3(0, H/2 - 1.0, 0)
	light.light_energy = 1.8
	light.omni_range = 20.0
	add_child(light)
