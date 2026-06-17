# This script will manage initialization and other aspects global to the entire project
extends Node3D

const WELCOME_MIDI:String = "res://addons/midi/resources/arrangements/welcome.mid"
const LOOP_MIDI:String = "res://addons/midi/resources/arrangements/dontComeBack.mid"

# Starts up the MIDI player
func _ready():
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
		print("RhythmMidiPlayer: Note ON - Channel: ", channel.number, " Note: ", event.note, " Velocity: ", event.velocity)

func _on_intro_midi_finished():
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
