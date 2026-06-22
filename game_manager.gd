extends Node
## GameManager - Central singleton orchestrating run state, scene transitions, and MIDI music

static var instance: GameManager

signal run_started(run_data: RunData)
signal run_ended(victory: bool)
signal floor_changed(floor: int)
signal scene_transition_requested(target_scene: String, data: Dictionary)

enum GameState { MAP, COMBAT, SHOP, REST, BOSS, VICTORY, DEFEAT }

var current_state: GameState = GameState.MAP
var run_data: RunData = null
var current_scene: Node = null

func _init():
	instance = self

func start_new_run(seed: int = 0) -> void:
	run_data = SaveManager.instance.create_new_run(seed)
	MapManager.instance.generate_map(run_data.seed, run_data.floor)
	run_started.emit(run_data)
	transition_to_map()

func continue_run() -> void:
	run_data = SaveManager.instance.load_run()
	if run_data.seed == 0:
		start_new_run()
		return
	MapManager.instance.generate_map(run_data.seed, run_data.floor)
	if run_data.current_node_id != 0:
		MapManager.instance.current_node = MapManager.instance.get_node_at_grid_pos(Vector2i(run_data.current_node_id % 9, int(run_data.current_node_id / 9)))
		if MapManager.instance.current_node:
			MapManager.instance.current_node.visited = true
			MapManager.instance._calculate_available_paths()
	run_started.emit(run_data)
	transition_to_map()

func transition_to_map() -> void:
	current_state = GameState.MAP
	_change_scene("res://map.tscn", {})

func transition_to_combat(enemy_data: EnemyData, enemy_count: int = 1, is_boss: bool = false) -> void:
	current_state = GameState.BOSS if is_boss else GameState.COMBAT
	var data = {
		"enemy_data": enemy_data,
		"enemy_count": enemy_count,
		"is_boss": is_boss
	}
	_change_scene("res://combat.tscn", data)

func transition_to_shop(shop_data: ShopData) -> void:
	current_state = GameState.SHOP
	var data = { "shop_data": shop_data }
	_change_scene("res://shop.tscn", data)

func transition_to_rest() -> void:
	current_state = GameState.REST
	_change_scene("res://rest.tscn", {})

func _change_scene(scene_path: String, data: Dictionary) -> void:
	call_deferred("_deferred_change_scene", scene_path, data)

func _deferred_change_scene(scene_path: String, data: Dictionary) -> void:
	if current_scene:
		current_scene.queue_free()
	var packed_scene = ResourceLoader.load(scene_path)
	if packed_scene:
		current_scene = packed_scene.instantiate()
		get_tree().root.add_child(current_scene)
		if current_scene.has_method("setup"):
			current_scene.setup(data)
		_update_music_for_state()

func _update_music_for_state() -> void:
	match current_state:
		GameState.MAP:
			_set_midi_layers(["map"])
		GameState.COMBAT:
			_set_midi_layers(["combat"])
		GameState.BOSS:
			_set_midi_layers(["boss"])
		GameState.SHOP:
			_set_midi_layers(["shop"])
		GameState.REST:
			_set_midi_layers(["rest"])
		GameState.VICTORY:
			_set_midi_layers(["victory"])
		GameState.DEFEAT:
			_set_midi_layers(["defeat"])

func _set_midi_layers(active_layers: Array[String]) -> void:
	var loop_player = get_tree().root.find_child("LoopMidiPlayer")
	var rhythm_player = get_tree().root.find_child("RhythmMidiPlayer")
	if not loop_player or not rhythm_player:
		return
	
	var loop_targets := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var rhythm_targets := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	
	if "map" in active_layers:
		for i in range(0, 4):
			loop_targets[i] = 1.0
	if "combat" in active_layers:
		for i in range(4, 8):
			loop_targets[i] = 1.0
		for i in range(0, 4):
			rhythm_targets[i] = 1.0
	if "boss" in active_layers:
		for i in range(8, 12):
			loop_targets[i] = 1.0
		for i in range(0, 4):
			rhythm_targets[i] = 1.0
	if "shop" in active_layers:
		for i in range(12, 16):
			loop_targets[i] = 1.0
	if "rest" in active_layers:
		for i in range(0, 4):
			loop_targets[i] = 1.0
	
	for i in range(loop_player.channel_status.size()):
		_tween_channel(loop_player.channel_status[i], loop_targets[i])
	for i in range(rhythm_player.channel_status.size()):
		_tween_channel(rhythm_player.channel_status[i], rhythm_targets[i])

func _tween_channel(channel, target: float) -> void:
	if channel.mute:
		channel.mute = false
	var tween = create_tween().set_parallel(false)
	tween.tween_method(_set_volume.bind(channel), channel.volume if channel.volume > 0 else 0.001, target if target > 0 else 0.001, 0.4).set_ease(Tween.EASE_IN_OUT)

func _set_volume(val: float, channel) -> void:
	channel.volume = clamp(val, 0.0, 1.0)

func on_combat_victory(rewards: Dictionary) -> bool:
	run_data.bits += rewards.get("bits", 0)
	for item_id in rewards.get("items", []):
		SaveManager.instance.add_item(run_data, item_id)
	for tech_id in rewards.get("techniques", []):
		SaveManager.instance.add_technique(run_data, tech_id)
	for upgrade_id in rewards.get("upgrades", []):
		SaveManager.instance.add_upgrade(run_data, upgrade_id)
	
	run_data.enemies_defeated += rewards.get("enemies_defeated", 1)
	
	_check_palette_unlocks()
	
	var was_floor_complete = MapManager.instance.current_node and int(MapManager.instance.current_node.room_index / MapManager.instance.MAP_WIDTH) == 0
	MapManager.instance.complete_node()
	_save_run()
	return was_floor_complete

func on_combat_defeat() -> void:
	run_ended.emit(false)
	_change_scene("res://main_menu.tscn", {})

func on_floor_completed() -> void:
	if not run_data:
		return
	run_data.floor += 1
	floor_changed.emit(run_data.floor)
	_save_run()
	transition_to_map()

func _save_run() -> void:
	run_data.current_node_id = MapManager.instance.current_node.room_index if MapManager.instance.current_node else 0
	SaveManager.instance.save_run(run_data)

func _check_palette_unlocks() -> void:
	var pm = PaletteManager.instance
	if run_data.enemies_defeated >= 50:
		pm.unlock_palette(1)
	if run_data.floor >= 5:
		pm.unlock_palette(2)
	if run_data.bits >= 1000:
		pm.unlock_palette(3)
	if run_data.upgrades_owned.size() == 7:
		pm.unlock_palette(7)
	if run_data.techniques_owned.size() >= 10:
		pm.unlock_palette(6)

func get_run_data() -> RunData:
	return run_data

func pause_game() -> void:
	get_tree().paused = true
	_change_scene("res://pause_menu.tscn", {})

func resume_game() -> void:
	get_tree().paused = false
	if current_scene:
		current_scene.queue_free()
	_change_scene(_get_scene_for_state(), {})

func _get_scene_for_state() -> String:
	match current_state:
		GameState.MAP: return "res://map.tscn"
		GameState.COMBAT: return "res://combat.tscn"
		GameState.BOSS: return "res://combat.tscn"
		GameState.SHOP: return "res://shop.tscn"
		GameState.REST: return "res://rest.tscn"
	return "res://map.tscn"

func quit_to_menu() -> void:
	_save_run()
	if current_scene:
		current_scene.queue_free()
	run_data = null
	current_state = GameState.MAP
	_change_scene("res://main_menu.tscn", {})
