extends Control

# Drag your MidiPlayer node into this path in the inspector, or adjust the path
@onready var midi_player = $"../MidiPlayer" 
@onready var slider_container = $HBoxContainer

func _ready():
	# MIDI supports exactly 16 channels (0 through 15)
	for channel in range(16):
		var slider = VSlider.new()
		
		# MIDI volume goes from 0 (silent) to 127 (max)
		slider.min_value = 0
		slider.max_value = 127
		slider.value = 100 # Standard default MIDI volume
		
		# Make the sliders tall enough to easily click and drag
		slider.custom_minimum_size = Vector2(30, 200) 
		
		# Connect the slider to our function, and pass the channel number along with it!
		slider.value_changed.connect(_on_volume_slider_changed.bind(channel))
		
		# Add it to the screen
		slider_container.add_child(slider)

func _on_volume_slider_changed(new_volume: float, channel: int):
	# 1. Create a blank Godot MIDI Event object
	var midi_event = InputEventMIDI.new()
	
	# 2. Tell the event what kind of message it is (Control Change)
	midi_event.message = MIDI_MESSAGE_CONTROL_CHANGE
	
	# 3. Fill in the specific data
	midi_event.channel = channel
	midi_event.controller_number = 7 # 7 is the universal MIDI standard for Volume
	midi_event.controller_value = int(new_volume)
	
	# 4. Pass the single object to the plugin
	midi_player.receive_raw_midi_message(midi_event)
