extends Resource
class_name GameConfig

## GameConfig - Persistent configuration settings

@export var language: String = "en"
@export var master_volume: int = 100
@export var sfx_volume: int = 100
@export var music_volume: int = 100
@export var metronome_enabled: bool = false
@export var metronome_volume: int = 50
@export var visual_assist: bool = false
@export var reduced_motion: bool = false
@export var color_palette_id: int = 0

const CONFIG_PATH = "user://config.tres"

static func load() -> GameConfig:
	var config = GameConfig.new()
	var file = ConfigFile.new()
	if file.load(CONFIG_PATH) == OK:
		config.language = file.get_value("settings", "language", "en")
		config.master_volume = file.get_value("settings", "master_volume", 100)
		config.sfx_volume = file.get_value("settings", "sfx_volume", 100)
		config.music_volume = file.get_value("settings", "music_volume", 100)
		config.metronome_enabled = file.get_value("settings", "metronome_enabled", false)
		config.metronome_volume = file.get_value("settings", "metronome_volume", 50)
		config.visual_assist = file.get_value("settings", "visual_assist", false)
		config.reduced_motion = file.get_value("settings", "reduced_motion", false)
		config.color_palette_id = file.get_value("settings", "color_palette_id", 0)
	return config

func save() -> void:
	var file = ConfigFile.new()
	file.set_value("settings", "language", language)
	file.set_value("settings", "master_volume", master_volume)
	file.set_value("settings", "sfx_volume", sfx_volume)
	file.set_value("settings", "music_volume", music_volume)
	file.set_value("settings", "metronome_enabled", metronome_enabled)
	file.set_value("settings", "metronome_volume", metronome_volume)
	file.set_value("settings", "visual_assist", visual_assist)
	file.set_value("settings", "reduced_motion", reduced_motion)
	file.set_value("settings", "color_palette_id", color_palette_id)
	file.save(CONFIG_PATH)

func apply_audio_settings() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume / 100.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_volume / 100.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume / 100.0))

func linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)
