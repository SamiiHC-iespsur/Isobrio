# This script will manage initialization and other aspects global to the entire project
extends Node3D

const WELCOME_MIDI:String = "res://addons/midi/resources/arrangements/welcome.mid"
const LOOP_MIDI:String = "res://addons/midi/resources/arrangements/dontComeBack.mid"

@onready var black_screen = $UICanvasLayer/UIRoot/BlackScreen
@onready var title_screen = $UICanvasLayer/UIRoot/TitleScreen
@onready var logo_container = $UICanvasLayer/UIRoot/TitleScreen/LogoContainer

var note_count = 0
var title_screen_active = false
var main_menu: Control = null

# Starts up the MIDI player
func _ready():
	black_screen.show()
	title_screen.hide()
	
	$IntroMidiPlayer.finished.connect(_on_intro_midi_finished)
	$LoopMidiPlayer.prepare_playback()
	
	$RhythmMidiPlayer.play_speed = $LoopMidiPlayer.play_speed * 2.0
	for channel in $RhythmMidiPlayer.channel_status:
		channel.mute = true
	$RhythmMidiPlayer.midi_event.connect(_on_rhythm_midi_event)
	$RhythmMidiPlayer.prepare_playback()
	
	$IntroMidiPlayer.play()

func _on_rhythm_midi_event(channel, event):
	if event.type == 0x90:  # Note On
		note_count += 1
		if note_count % 2 == 1:
			_bounce_logo()

func _on_intro_midi_finished():
	title_screen.show()
	title_screen_active = true
	
	$LoopMidiPlayer.play()
	$RhythmMidiPlayer.play()

# Sets up the fullscreen toggle available via keyboard shortcuts (F11 or Alt+Enter) [AND FROM OPTIONS MENU IN THE FUTURE]
func _fullscreen_toggle():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			_fullscreen_toggle()
		elif title_screen_active and event.keycode != KEY_F11:
			_on_title_screen_pressed()

func _on_title_screen_pressed():
	title_screen_active = false
	_show_main_menu()

func _show_main_menu():
	title_screen.hide()
	var main_menu_scene = load("res://main_menu.tscn")
	main_menu = main_menu_scene.instantiate()
	$UICanvasLayer.add_child(main_menu)
	main_menu.start_new_game.connect(_on_start_new_game)
	main_menu.continue_game.connect(_on_continue_game)
	main_menu.quit_game.connect(_on_quit_game)
	main_menu.open_settings.connect(_on_open_settings.bind(main_menu))

func _on_open_settings(main_menu_node: Control) -> void:
	var settings = load("res://settings_menu.tscn").instantiate()
	main_menu_node.add_child(settings)
	settings.settings_changed.connect(_on_settings_changed)

func _on_settings_changed() -> void:
	pass

func _on_start_new_game() -> void:
	main_menu.hide()
	var cinematic = load("res://cinematic.tscn").instantiate()
	$UICanvasLayer.add_child(cinematic)
	cinematic.cinematic_finished.connect(_on_cinematic_finished)

func _on_cinematic_finished() -> void:
	$UICanvasLayer.queue_free()
	GameManager.start_new_run()

func _on_continue_game() -> void:
	$UICanvasLayer.queue_free()
	GameManager.continue_run()

func _on_quit_game() -> void:
	get_tree().quit()

func _bounce_logo():
	logo_container.scale = Vector2(1.2, 1.2)
	var tween = create_tween()
	tween.tween_property(logo_container, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
