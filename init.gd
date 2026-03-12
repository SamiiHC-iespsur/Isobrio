# This script will manage initialization and other aspects global to the entire project
extends Node3D

# Starts up the MIDI player
func _ready():
	$MidiPlayer.play();

# Sets up the fullscreen toggle available via keyboard shortcuts (F11 or Alt+Enter) [AND FROM OPTIONS MENU IN THE FUTURE]
func _fullscreen_toggle():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _input(event):
	if event is InputEventKey and event.pressed and (event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed)):
		_fullscreen_toggle()

