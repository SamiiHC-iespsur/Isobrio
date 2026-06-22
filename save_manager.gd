extends Node
## SaveManager - Handles game save/load with .tres files

static var instance: SaveManager

const SAVE_PATH = "user://save.tres"
const RUN_DATA_PATH = "user://run_data.tres"

signal game_saved
signal game_loaded
signal save_failed
signal load_failed

func _init():
	instance = self

func save_run(run_data: RunData) -> bool:
	var resource = ResourceSaver.save(run_data, RUN_DATA_PATH)
	if resource == OK:
		game_saved.emit()
		return true
	else:
		save_failed.emit()
		return false

func load_run() -> RunData:
	var resource = ResourceLoader.load(RUN_DATA_PATH)
	if resource:
		game_loaded.emit()
		return resource
	else:
		load_failed.emit()
		return RunData.new()

func has_save() -> bool:
	return FileAccess.file_exists(RUN_DATA_PATH)

func delete_save() -> void:
	if FileAccess.file_exists(RUN_DATA_PATH):
		DirAccess.remove_absolute(RUN_DATA_PATH)

func create_new_run(seed: int = 0) -> RunData:
	var data = RunData.new()
	data.seed = seed if seed != 0 else randi()
	data.current_node_id = 0
	data.play_time = 0.0
	data.vit_current = 100
	data.vit_max = 100
	data.brio_current = 0
	data.brio_max = 100
	data.bits = 0
	data.inventory = {}
	data.floor = 1
	data.enemies_defeated = 0
	return data

func update_play_time(run_data: RunData, delta: float) -> void:
	run_data.play_time += delta

func format_play_time(seconds: float) -> String:
	var total_secs = int(seconds)
	var hours = total_secs / 3600
	var minutes = (total_secs % 3600) / 60
	var secs = total_secs % 60
	return "%02d:%02d:%02d" % [hours, minutes, secs]

func add_bits(run_data: RunData, amount: int) -> void:
	run_data.bits += amount

func spend_bits(run_data: RunData, amount: int) -> bool:
	if run_data.bits >= amount:
		run_data.bits -= amount
		return true
	return false

func add_item(run_data: RunData, item_id: int, amount: int = 1) -> void:
	var current = run_data.inventory.get(item_id, 0)
	run_data.inventory[item_id] = current + amount

func remove_item(run_data: RunData, item_id: int, amount: int = 1) -> bool:
	var current = run_data.inventory.get(item_id, 0)
	if current >= amount:
		run_data.inventory[item_id] = current - amount
		if run_data.inventory[item_id] <= 0:
			run_data.inventory.erase(item_id)
		return true
	return false

func get_item_count(run_data: RunData, item_id: int) -> int:
	return run_data.inventory.get(item_id, 0)

func add_technique(run_data: RunData, technique_id: int) -> void:
	if technique_id not in run_data.techniques_owned:
		run_data.techniques_owned.append(technique_id)

func add_upgrade(run_data: RunData, upgrade_id: int) -> void:
	if upgrade_id not in run_data.upgrades_owned:
		run_data.upgrades_owned.append(upgrade_id)

func heal_vit(run_data: RunData, amount: int) -> void:
	run_data.vit_current = min(run_data.vit_current + amount, run_data.vit_max)

func damage_vit(run_data: RunData, amount: int) -> void:
	run_data.vit_current = max(run_data.vit_current - amount, 0)

func add_brio(run_data: RunData, amount: int) -> void:
	run_data.brio_current = min(run_data.brio_current + amount, run_data.brio_max)

func spend_brio(run_data: RunData, amount: int) -> bool:
	if run_data.brio_current >= amount:
		run_data.brio_current -= amount
		return true
	return false

func unlock_palette(palette_id: int) -> void:
	var config = GameConfig.load()
	if palette_id not in config.palettes_unlocked:
		config.palettes_unlocked.append(palette_id)
		config.save()
		PaletteManager.instance.unlock_palette(palette_id)
