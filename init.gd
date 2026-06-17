# This script will manage initialization and other aspects global to the entire project
extends Node3D

const WELCOME_MIDI:String = "res://addons/midi/resources/arrangements/welcome.mid"
const LOOP_MIDI:String = "res://addons/midi/resources/arrangements/dontComeBack.mid"

@onready var black_screen = $UICanvasLayer/UIRoot/BlackScreen
@onready var title_screen = $UICanvasLayer/UIRoot/TitleScreen
@onready var logo_container = $UICanvasLayer/UIRoot/TitleScreen/LogoContainer

var note_count = 0

# Starts up the MIDI player
func _ready():
	black_screen.show()
	title_screen.hide()
	
	print("logo_container: ", logo_container, " scale: ", logo_container.scale)
	print("title_screen visible: ", title_screen.visible)
	
	$IntroMidiPlayer.finished.connect( _on_intro_midi_finished )
	$LoopMidiPlayer.prepare_playback( )
	
	$RhythmMidiPlayer.play_speed = $LoopMidiPlayer.play_speed * 2.0
	for channel in $RhythmMidiPlayer.channel_status:
		channel.mute = true
	$RhythmMidiPlayer.midi_event.connect(_on_rhythm_midi_event)
	$RhythmMidiPlayer.prepare_playback( )
	
	$IntroMidiPlayer.play( )

func _on_rhythm_midi_event(channel, event):
	if event.type == 0x90:  # Note On
		print("BEAT!")
		note_count += 1
		if note_count % 2 == 1:
			_bounce_logo()

func _on_intro_midi_finished():
	title_screen.show()
	
	$LoopMidiPlayer.play( )
	$RhythmMidiPlayer.play( )

# Sets up the fullscreen toggle available via keyboard shortcuts (F11 or Alt+Enter) [AND FROM OPTIONS MENU IN THE FUTURE]
func _fullscreen_toggle():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _input(event):
	if event is InputEventKey and event.pressed and (event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed)):
		_fullscreen_toggle()

func _bounce_logo():
	print("BOUNCING! logo_container scale before: ", logo_container.scale)
	logo_container.scale = Vector2(1.2, 1.2)
	var tween = create_tween()
	tween.tween_property(logo_container, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): print("Tween finished! logo_container scale after: ", logo_container.scale))
