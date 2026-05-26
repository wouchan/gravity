extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var spawn_point: Marker3D = $TestLevel/SpawnPoint

func _ready() -> void:
	_reset_player()

func _reset_player() -> void:
	player.global_transform = spawn_point.global_transform
