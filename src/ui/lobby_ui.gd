extends CanvasLayer

@onready var panel := Panel.new()
@onready var layout := VBoxContainer.new()
@onready var title := Label.new()
@onready var host_btn := Button.new()
@onready var ip_input := LineEdit.new()
@onready var join_btn := Button.new()
@onready var status_label := Label.new()

func _ready() -> void:
	_build_ui()
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	SceneLoader.load_progress.connect(_on_load_progress)

func _build_ui() -> void:
	panel.size = get_viewport().get_visible_rect().size
	panel.modulate.a = 0.85
	add_child(panel)

	layout.add_theme_constant_override("separation", 12)
	layout.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	layout.anchors_preset = Control.PRESET_CENTER
	panel.add_child(layout)

	title.text = "OverCraft"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	layout.add_child(title)

	host_btn.text = "Host Game"
	host_btn.custom_minimum_size = Vector2(240, 48)
	layout.add_child(host_btn)

	ip_input.placeholder_text = "127.0.0.1"
	ip_input.custom_minimum_size = Vector2(240, 36)
	layout.add_child(ip_input)

	join_btn.text = "Join Game"
	join_btn.custom_minimum_size = Vector2(240, 48)
	layout.add_child(join_btn)

	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.modulate.a = 0.6
	layout.add_child(status_label)

func _on_host() -> void:
	status_label.text = "Loading map..."
	host_btn.disabled = true
	join_btn.disabled = true
	SceneLoader.load_scene("res://scenes/test_level1.tscn", NetworkManager.host)

func _on_join() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	status_label.text = "Connecting to %s..." % ip
	join_btn.disabled = true
	NetworkManager.join(ip)

func _on_connected() -> void:
	status_label.text = "Connected, loading map..."
	SceneLoader.load_scene("res://scenes/test_level1.tscn")

func _on_connect_failed() -> void:
	status_label.text = "Connection failed"
	join_btn.disabled = false

func _on_load_progress(progress: float) -> void:
	status_label.text = "Loading... %d%%" % (progress * 100)
