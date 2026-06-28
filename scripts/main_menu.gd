extends Control

const LEVEL_1 := "res://scenes/level_1.tscn"
const LEVEL_2 := "res://scenes/level_2.tscn"
const LEVEL_3 := "res://scenes/level_3.tscn"

var _main     : VBoxContainer
var _levels   : VBoxContainer
var _settings : VBoxContainer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE     # re-show cursor after gameplay
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_main()
	_build_levels()
	_build_settings()
	_show_only(_main)

# ── Panel switching ───────────────────────────────────────────────────
func _show_only(panel: Control) -> void:
	_main.visible     = (panel == _main)
	_levels.visible   = (panel == _levels)
	_settings.visible = (panel == _settings)

# ── UI helpers ────────────────────────────────────────────────────────
func _make_panel() -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)
	return vbox

func _title(parent: Node, text: String, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)

func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 46)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

# ── Main panel ────────────────────────────────────────────────────────
func _build_main() -> void:
	_main = _make_panel()
	_title(_main, "GRAVITY", 48)
	_title(_main, "DEMO", 24)
	_button(_main, "Play",     func(): _show_only(_levels))
	_button(_main, "Settings", func(): _show_only(_settings))
	_button(_main, "Quit",     func(): get_tree().quit())

# ── Level select ──────────────────────────────────────────────────────
func _build_levels() -> void:
	_levels = _make_panel()
	_title(_levels, "SELECT LEVEL", 32)
	_button(_levels, "Level 1", func(): get_tree().change_scene_to_file(LEVEL_1))
	_button(_levels, "Level 2", func(): get_tree().change_scene_to_file(LEVEL_2))
	_button(_levels, "Level 3", func(): get_tree().change_scene_to_file(LEVEL_3))
	_button(_levels, "Back",    func(): _show_only(_main))

# ── Settings ──────────────────────────────────────────────────────────
func _build_settings() -> void:
	_settings = _make_panel()
	_title(_settings, "SETTINGS", 32)

	# Fullscreen
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(_on_fullscreen_toggled)
	_settings.add_child(fs)

	# Volume
	var vlabel := Label.new()
	vlabel.text = "Master Volume"
	_settings.add_child(vlabel)

	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.01
	vol.custom_minimum_size = Vector2(240, 0)
	var bus := AudioServer.get_bus_index("Master")
	vol.value = db_to_linear(AudioServer.get_bus_volume_db(bus))
	vol.value_changed.connect(_on_volume_changed)
	_settings.add_child(vol)

	_button(_settings, "Back", func(): _show_only(_main))

func _on_fullscreen_toggled(on: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)

func _on_volume_changed(v: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)))  # avoid -inf at 0
