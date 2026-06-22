extends Control
class_name CinematicPlayer

@onready var video_player = $VideoStreamPlayer

signal cinematic_finished

var paused := false

func _ready() -> void:
	var stream = VideoStreamTheora.new()
	stream.set_file("res://visual/video.ogv")
	video_player.stream = stream
	video_player.volume_db = -80
	video_player.finished.connect(_on_video_finished)
	video_player.play()

func _input(event: InputEvent) -> void:
	if not paused and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		paused = true
		video_player.paused = true
		var settings = load("res://settings_menu.tscn").instantiate()
		add_child(settings)
		settings.tree_exited.connect(_on_settings_closed)

func _on_settings_closed() -> void:
	paused = false
	video_player.paused = false

func _on_video_finished() -> void:
	cinematic_finished.emit()
	queue_free()
