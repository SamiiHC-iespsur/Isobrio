extends Node

## PaletteManager - Handles color palette system (like Downwell)

static var instance: PaletteManager

@export var palettes: Array = []

const PALETTE_PATH = "user://palettes.tres"

var _initialized := false

func _init():
	instance = self

func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_setup_default_palettes()
	_load_palettes()

func _make_palette(p_id: int, p_name: String, c1: Color, c2: Color, c3: Color, unlocked: bool, condition: String) -> ColorPalette:
	var p = ColorPalette.new()
	p.palette_id = p_id
	p.palette_name = p_name
	p.color_1 = c1
	p.color_2 = c2
	p.color_3 = c3
	p.unlocked = unlocked
	p.unlock_condition = condition
	return p

func _setup_default_palettes() -> void:
	palettes = [
		_make_palette(0, "Default", Color(0.1, 0.1, 0.15), Color(0.9, 0.85, 0.7), Color(0.4, 0.7, 0.9), true, ""),
		_make_palette(1, "Crimson", Color(0.15, 0.0, 0.05), Color(0.9, 0.2, 0.3), Color(0.6, 0.1, 0.2), false, "Defeat 50 enemies"),
		_make_palette(2, "Emerald", Color(0.0, 0.15, 0.05), Color(0.2, 0.9, 0.4), Color(0.1, 0.6, 0.3), false, "Reach floor 5"),
		_make_palette(3, "Violet", Color(0.1, 0.0, 0.15), Color(0.7, 0.3, 0.9), Color(0.4, 0.2, 0.6), false, "Collect 1000 Bits"),
		_make_palette(4, "Gold", Color(0.15, 0.1, 0.0), Color(1.0, 0.85, 0.2), Color(0.8, 0.6, 0.1), false, "Win a run"),
		_make_palette(5, "Monochrome", Color(0.05, 0.05, 0.05), Color(0.95, 0.95, 0.95), Color(0.5, 0.5, 0.5), false, "Complete 10 runs"),
		_make_palette(6, "Neon", Color(0.05, 0.0, 0.1), Color(0.0, 1.0, 1.0), Color(1.0, 0.0, 1.0), false, "Unlock all techniques"),
		_make_palette(7, "Pastel", Color(0.15, 0.1, 0.15), Color(0.9, 0.7, 0.8), Color(0.7, 0.8, 0.9), false, "Unlock all upgrades"),
	]

func _load_palettes() -> void:
	var file = ConfigFile.new()
	if file.load(PALETTE_PATH) == OK:
		for i in range(palettes.size()):
			var section = "palette_%d" % i
			if file.has_section_key(section, "unlocked"):
				palettes[i].unlocked = file.get_value(section, "unlocked", false)

func _save_palettes() -> void:
	_ensure_initialized()
	var file = ConfigFile.new()
	for i in range(palettes.size()):
		var section = "palette_%d" % i
		file.set_value(section, "unlocked", palettes[i].unlocked)
	file.save(PALETTE_PATH)

func get_current_palette() -> ColorPalette:
	_ensure_initialized()
	var config = GameConfig.load()
	return palettes[config.color_palette_id]

func set_palette(id: int) -> bool:
	_ensure_initialized()
	if id < 0 or id >= palettes.size():
		return false
	if not palettes[id].unlocked:
		return false
	var config = GameConfig.load()
	config.color_palette_id = id
	config.save()
	return true

func unlock_palette(id: int) -> void:
	_ensure_initialized()
	if id >= 0 and id < palettes.size():
		palettes[id].unlocked = true
		_save_palettes()

func get_unlocked_palettes() -> Array[ColorPalette]:
	_ensure_initialized()
	var result = []
	for p in palettes:
		if p.unlocked:
			result.append(p)
	return result

func apply_palette_to_sprite(sprite: Sprite2D, palette_index: int = 0) -> void:
	var palette = get_current_palette()
	var colors = [palette.color_1, palette.color_2, palette.color_3]
	if palette_index < colors.size():
		sprite.modulate = colors[palette_index]

func apply_palette_to_canvas_item(item: CanvasItem, palette_index: int = 0) -> void:
	var palette = get_current_palette()
	var colors = [palette.color_1, palette.color_2, palette.color_3]
	if palette_index < colors.size():
		item.modulate = colors[palette_index]
