extends Node3D

@export var next_scene   : PackedScene          # next level, or main_menu on level 3
@export var win_delay    : float = 0.6          # lets the last enemy's death play out

var _enemies_left := 0
var _advancing    := false

func _ready() -> void:
	_track_enemies()

# ── Win condition ─────────────────────────────────────────────────────
func _track_enemies() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	_enemies_left = enemies.size()
	for e in enemies:
		if e.has_signal("died"):
			e.died.connect(_on_enemy_died)
	if _enemies_left == 0:
		_advance()                              # empty level → pass straight through

func _on_enemy_died() -> void:
	_enemies_left -= 1
	if _enemies_left <= 0 and not _advancing:
		_advance()

func _advance() -> void:
	_advancing = true
	if next_scene == null:
		push_warning("level.gd: next_scene not assigned")
		return
	await get_tree().create_timer(win_delay).timeout
	if is_inside_tree():                        # guard: player may have reloaded us
		get_tree().change_scene_to_packed(next_scene)
