extends CanvasLayer
class_name CombatScene

enum State { START, PLAYER_ACTION_SELECT, PLAYER_TIMING_WINDOW, PLAYER_RESOLVE, ENEMY_TURN, VICTORY, DEFEAT }
enum TimingGrade { PERFECT, GOOD, OK, MISS }
enum ProjectilePattern { LINEAR, EASE_IN, EASE_OUT, MULTI }

const PERFECT_MS = 0.05
const GOOD_MS = 0.1
const OK_MS = 0.2
const ATTACK_BASE_DMG = 15
const BRIO_ON_PERFECT = 5
const BRIO_ON_GOOD = 3
const BRIO_ON_OK = 1
const LANE_BASE = 2
const LANE_PER_ENEMY = 1
const LANE_PER_BOSS = 3
const PROJ_SPEED_BASE = 0.8
const ENEMY_PHASE_LENGTH = 4

var state: State = State.START
var enemies: Array = []
var player_vit: int = 100
var player_vit_max: int = 100
var player_brio: int = 0
var player_brio_max: int = 100
var player_defending: bool = false
var player_lane: int = 0
var lane_count: int = LANE_BASE
var is_boss_fight: bool = false

var last_beat_time: float = 0.0
var beat_interval: float = 0.5
var beat_timer: float = 0.0
var beat_pulse: float = 0.0
var timing_result: TimingGrade = TimingGrade.MISS
var timing_mult: float = 1.0
var sequence_inputs: Array = []
var sequence_index: int = 0
var sequence_results: Array = []
var current_action_type: String = ""
var selected_technique: Resource = null
var selected_item: Resource = null
var action_power: int = 0
var action_damage: int = 0

var projectiles: Array = []
var enemy_timer: float = 0.0
var enemy_phase_beats: int = 0
var enemy_attack_power: int = 8

@onready var arena = $Arena
@onready var arena_bg = $Arena/ArenaBg
@onready var player_node = $Arena/Player
@onready var player_sprite = $Arena/Player/Sprite
@onready var enemy_root = $Arena/Enemies
@onready var proj_root = $Arena/Projectiles
@onready var vit_bar = $HUD/PlayerBars/VITBar
@onready var vit_label = $HUD/PlayerBars/VITLabel
@onready var brio_bar = $HUD/PlayerBars/BRIOBar
@onready var brio_label = $HUD/PlayerBars/BRIOLabel
@onready var turn_label = $HUD/TurnLabel
@onready var action_panel = $HUD/ActionPanel
@onready var btn_attack = $HUD/ActionPanel/Attack
@onready var btn_technique = $HUD/ActionPanel/Technique
@onready var btn_item = $HUD/ActionPanel/Item
@onready var btn_defend = $HUD/ActionPanel/Defend
@onready var btn_flee = $HUD/ActionPanel/Flee
@onready var timing_panel = $HUD/TimingPanel
@onready var timing_icon = $HUD/TimingPanel/Icon
@onready var timing_label = $HUD/TimingPanel/GradeLabel
@onready var beat_indicator = $HUD/TimingPanel/BeatIndicator
@onready var battle_log = $HUD/BattleLog
@onready var tech_panel = $HUD/TechniquePanel
@onready var tech_list = $HUD/TechniquePanel/ScrollContainer/Grid
@onready var item_panel = $HUD/ItemPanel
@onready var item_list = $HUD/ItemPanel/ScrollContainer/Grid
@onready var lane_markers = $Arena/LaneMarkers
@onready var lane_highlight = $Arena/LaneHighlight
@onready var enemy_bars = $HUD/EnemyBars

func setup(data: Dictionary) -> void:
	var enemy_data = data.get("enemy_data", null)
	var count = data.get("enemy_count", 1)
	is_boss_fight = data.get("is_boss", false)
	_setup_combat(enemy_data, count)

func _ready() -> void:
	_find_midi_player()
	_update_bars()

func _setup_combat(enemy_data, count: int) -> void:
	if GameManager.instance and GameManager.instance.run_data:
		player_vit_max = GameManager.instance.run_data.vit_max
		player_vit = GameManager.instance.run_data.vit_current
		player_brio_max = GameManager.instance.run_data.brio_max
		player_brio = GameManager.instance.run_data.brio_current
	
	lane_count = LANE_BASE
	if enemy_data:
		for i in range(count):
			var inst = _create_enemy_instance(enemy_data, i)
			enemies.append(inst)
			if enemy_data.is_boss:
				lane_count += LANE_PER_BOSS
			else:
				lane_count += LANE_PER_ENEMY
	
	_build_arena()
	action_panel.show()
	timing_panel.hide()
	tech_panel.hide()
	item_panel.hide()
	_set_state(State.PLAYER_ACTION_SELECT)

func _find_midi_player() -> void:
	var rp = get_tree().root.find_child("RhythmMidiPlayer", true, false)
	if rp and rp.has_signal("midi_event"):
		rp.midi_event.connect(_on_midi_event)
		beat_interval = 0.5

func _on_midi_event(_channel, event) -> void:
	if event.type == 0x90:
		last_beat_time = Time.get_ticks_usec() / 1000000.0
		_on_beat()

func _process(delta: float) -> void:
	beat_timer += delta
	if not _midi_available():
		if beat_timer >= beat_interval:
			beat_timer -= beat_interval
			last_beat_time = Time.get_ticks_usec() / 1000000.0
			_on_beat()
	
	beat_pulse = move_toward(beat_pulse, 0.0, delta * 4.0)
	beat_indicator.modulate.a = beat_pulse
	
	match state:
		State.ENEMY_TURN:
			_update_enemy_phase(delta)
		State.VICTORY, State.DEFEAT:
			pass

func _on_beat() -> void:
	beat_pulse = 1.0
	beat_indicator.scale = Vector2(1.3, 1.3)
	var tween = create_tween()
	tween.tween_property(beat_indicator, "scale", Vector2(1.0, 1.0), 0.15)
	tween.tween_property(arena_bg, "color", Color(0.12, 0.12, 0.18, 0.85), 0.05).set_ease(Tween.EASE_OUT)
	tween.tween_property(arena_bg, "color", Color(0.08, 0.08, 0.12, 0.85), 0.15).set_ease(Tween.EASE_IN)

func _midi_available() -> bool:
	return get_tree().root.find_child("RhythmMidiPlayer", true, false) != null

func _set_state(new_state: State) -> void:
	state = new_state
	match state:
		State.PLAYER_ACTION_SELECT:
			turn_label.text = tr("combat_player_turn")
			action_panel.show()
			timing_panel.hide()
		State.PLAYER_TIMING_WINDOW:
			action_panel.hide()
			timing_panel.show()
			if current_action_type == "technique":
				var tech = selected_technique
				if tech:
					sequence_index = 0
					sequence_results = []
			timing_label.text = ""
			timing_icon.modulate = Color(1, 1, 1, 0)
		State.PLAYER_RESOLVE:
			timing_panel.hide()
		State.ENEMY_TURN:
			turn_label.text = tr("combat_enemy_turn")
			enemy_timer = 0.0
			enemy_phase_beats = 0
			action_panel.hide()
			timing_panel.hide()

func _on_attack_pressed() -> void:
	_set_action("attack")

func _on_technique_pressed() -> void:
	_show_technique_select()

func _on_item_pressed() -> void:
	_show_item_select()

func _on_defend_pressed() -> void:
	player_defending = true
	_log_message(tr("combat_action_defend"))
	_end_player_turn()

func _on_flee_pressed() -> void:
	_set_action("flee")

func _set_action(action: String) -> void:
	if state != State.PLAYER_ACTION_SELECT:
		return
	current_action_type = action
	match action:
		"attack":
			action_power = ATTACK_BASE_DMG
			_set_state(State.PLAYER_TIMING_WINDOW)
		"flee":
			_set_state(State.PLAYER_TIMING_WINDOW)
		_:
			_set_state(State.PLAYER_TIMING_WINDOW)

func _show_technique_select() -> void:
	if not GameManager.instance or not GameManager.instance.run_data:
		return
	action_panel.hide()
	tech_panel.show()
	for child in tech_list.get_children():
		child.queue_free()
	var tech_ids = GameManager.instance.run_data.techniques_owned
	for tid in tech_ids:
		var tech = _load_technique(tid)
		if not tech:
			continue
		var btn = Button.new()
		btn.text = tech.get_technique_name() + " (" + tr("combat_brio_cost") % tech.brio_cost + ")"
		btn.disabled = player_brio < tech.brio_cost
		btn.pressed.connect(_on_technique_selected.bind(tech))
		tech_list.add_child(btn)
	var back = Button.new()
	back.text = tr("settings_back")
	back.pressed.connect(_hide_technique_select)
	tech_list.add_child(back)

func _hide_technique_select() -> void:
	tech_panel.hide()
	action_panel.show()

func _on_technique_selected(tech) -> void:
	tech_panel.hide()
	selected_technique = tech
	player_brio -= tech.brio_cost
	_update_bars()
	_set_action("technique")

func _show_item_select() -> void:
	if not GameManager.instance or not GameManager.instance.run_data:
		return
	action_panel.hide()
	item_panel.show()
	for child in item_list.get_children():
		child.queue_free()
	var inv = GameManager.instance.run_data.inventory
	for item_id in inv.keys():
		var qty = inv[item_id]
		var item = _load_item(item_id)
		if not item:
			continue
		var btn = Button.new()
		btn.text = item.get_item_name() + " x" + str(qty)
		btn.pressed.connect(_on_item_selected.bind(item))
		item_list.add_child(btn)
	var back = Button.new()
	back.text = tr("settings_back")
	back.pressed.connect(_hide_item_select)
	item_list.add_child(back)

func _hide_item_select() -> void:
	item_panel.hide()
	action_panel.show()

func _on_item_selected(item) -> void:
	item_panel.hide()
	selected_item = item
	_use_item(item)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		if state == State.ENEMY_TURN:
			player_lane = max(0, player_lane - 1)
			_update_player_lane()
	elif event.is_action_pressed("ui_down"):
		if state == State.ENEMY_TURN:
			player_lane = min(lane_count - 1, player_lane + 1)
			_update_player_lane()
	elif event.is_action_pressed("ui_accept"):
		if state == State.PLAYER_TIMING_WINDOW:
			_on_timing_input()

func _on_timing_input() -> void:
	var now = Time.get_ticks_usec() / 1000000.0
	var since_beat = now - last_beat_time
	var dist = min(since_beat, beat_interval - since_beat)
	
	if dist <= PERFECT_MS:
		timing_result = TimingGrade.PERFECT
	elif dist <= GOOD_MS:
		timing_result = TimingGrade.GOOD
	elif dist <= OK_MS:
		timing_result = TimingGrade.OK
	else:
		timing_result = TimingGrade.MISS
	
	_show_timing_feedback(timing_result)
	
	if current_action_type == "technique" and selected_technique:
		var tech = selected_technique
		if sequence_index < tech.inputs.size():
			if tech.inputs[sequence_index] == 1:
				sequence_results.append(timing_result)
			sequence_index += 1
			if sequence_index >= tech.inputs.size():
				_resolve_technique()
			else:
				timing_label.text = "%d / %d" % [sequence_index, tech.inputs.size()]
	elif current_action_type == "attack":
		_resolve_attack()
	elif current_action_type == "flee":
		_resolve_flee()

func _show_timing_feedback(grade: TimingGrade) -> void:
	var tween = create_tween()
	match grade:
		TimingGrade.PERFECT:
			timing_label.text = tr("combat_perfect_timing")
			timing_label.modulate = Color(1, 1, 0)
			timing_icon.modulate = Color(1, 0.85, 0)
		TimingGrade.GOOD:
			timing_label.text = tr("combat_good_timing")
			timing_label.modulate = Color(0, 1, 0)
			timing_icon.modulate = Color(0, 1, 0)
		TimingGrade.OK:
			timing_label.text = tr("combat_ok_timing")
			timing_label.modulate = Color(1, 1, 1)
			timing_icon.modulate = Color(1, 1, 1)
		TimingGrade.MISS:
			timing_label.text = tr("combat_miss_timing")
			timing_label.modulate = Color(1, 0, 0)
			timing_icon.modulate = Color(1, 0, 0)
	timing_label.modulate.a = 0
	tween.tween_property(timing_label, "modulate:a", 1.0, 0.05)

func _resolve_attack() -> void:
	var mult = _timing_to_mult(timing_result)
	action_damage = int(action_power * mult)
	var total_dmg = 0
	for enemy in enemies:
		if enemy.vit > 0:
			var dmg = _calculate_damage(action_damage, enemy)
			enemy.vit -= dmg
			total_dmg += dmg
			_log_message(tr("combat_damage_dealt") % dmg)
			if enemy.vit <= 0:
				_log_message(tr("combat_enemy_defeated") % enemy.data.get_enemy_name())
			_update_enemy_bar(enemy)
	_add_brio(timing_result)
	if total_dmg > 0:
		_animate_player_attack()
	else:
		_end_player_turn()

func _resolve_technique() -> void:
	var tech = selected_technique
	var avg = _average_timing(sequence_results)
	var mult = _timing_to_mult(avg)
	
	match tech.type:
		0: _resolve_rhythm_tech(tech, mult); _end_player_turn()
		1: _resolve_attack_tech(tech, mult)
		2: _resolve_multi_tech(tech, mult)
		3: _resolve_heal_tech(tech, mult); _end_player_turn()

func _resolve_rhythm_tech(tech, mult: float) -> void:
	var bonus_brio = int(10 * mult)
	player_brio = min(player_brio_max, player_brio + bonus_brio)
	_log_message(tech.get_technique_name() + " +" + str(bonus_brio) + " BRIO")
	_update_bars()

func _resolve_attack_tech(tech, mult: float) -> void:
	var dmg = int(tech.power * mult)
	for enemy in enemies:
		if enemy.vit > 0:
			enemy.vit -= dmg
			_log_message(tr("combat_damage_dealt") % dmg)
			if enemy.vit <= 0:
				_log_message(tr("combat_enemy_defeated") % enemy.data.get_enemy_name())
			_update_enemy_bar(enemy)
	_animate_player_attack()

func _resolve_multi_tech(tech, mult: float) -> void:
	var dmg = int(tech.power * mult)
	var hit_count = 0
	for enemy in enemies:
		if enemy.vit > 0:
			enemy.vit -= dmg
			hit_count += 1
			if enemy.vit <= 0:
				_log_message(tr("combat_enemy_defeated") % enemy.data.get_enemy_name())
			_update_enemy_bar(enemy)
	if hit_count > 0:
		_animate_player_attack()
		_log_message(tr("combat_damage_dealt") % (dmg * hit_count))

func _resolve_heal_tech(tech, mult: float) -> void:
	var heal = int(tech.power * mult)
	player_vit = min(player_vit_max, player_vit + heal)
	_log_message(tr("combat_healed") % heal)
	_update_bars()

func _resolve_flee() -> void:
	if timing_result != TimingGrade.MISS:
		_log_message("Fled!")
		if GameManager.instance:
			GameManager.instance.transition_to_map()
	else:
		_log_message("Failed to flee!")
		_end_player_turn()

func _timing_to_mult(grade) -> float:
	if grade is Array:
		return _timing_to_mult(_average_timing(grade))
	match grade:
		TimingGrade.PERFECT: return 1.5
		TimingGrade.GOOD: return 1.2
		TimingGrade.OK: return 1.0
		TimingGrade.MISS: return 0.5
	return 1.0

func _average_timing(results: Array) -> TimingGrade:
	if results.is_empty():
		return TimingGrade.MISS
	var score = 0.0
	for r in results:
		match r:
			TimingGrade.PERFECT: score += 1.0
			TimingGrade.GOOD: score += 0.8
			TimingGrade.OK: score += 0.6
			TimingGrade.MISS: score += 0.2
	score /= results.size()
	if score >= 0.9: return TimingGrade.PERFECT
	if score >= 0.7: return TimingGrade.GOOD
	if score >= 0.5: return TimingGrade.OK
	return TimingGrade.MISS

func _add_brio(grade) -> void:
	var gain = 0
	match grade:
		TimingGrade.PERFECT: gain = BRIO_ON_PERFECT
		TimingGrade.GOOD: gain = BRIO_ON_GOOD
		TimingGrade.OK: gain = BRIO_ON_OK
	player_brio = min(player_brio_max, player_brio + gain)
	_update_bars()

func _calculate_damage(base: int, enemy) -> int:
	return max(1, base)

func _use_item(item) -> void:
	if not GameManager.instance or not GameManager.instance.run_data:
		return
	var inv = GameManager.instance.run_data.inventory
	var qty = inv.get(item.id, 0)
	if qty <= 0:
		return
	if qty == 1:
		inv.erase(item.id)
	else:
		inv[item.id] = qty - 1
	
	match item.type:
		0: _use_rhythm_item(item)
		1: _use_vit_item(item)
		2: _use_brio_item(item)
	
	_end_player_turn()

func _use_rhythm_item(item) -> void:
	_log_message(item.get_item_name() + " " + tr("item_use"))

func _use_vit_item(item) -> void:
	var heal = item.intensity
	if heal >= 999:
		player_vit = player_vit_max
	else:
		player_vit = min(player_vit_max, player_vit + heal)
	_log_message(tr("combat_healed") % (player_vit_max if item.intensity >= 999 else item.intensity))
	_update_bars()

func _use_brio_item(item) -> void:
	var gain = item.intensity
	if gain >= 999:
		player_brio = player_brio_max
	else:
		player_brio = min(player_brio_max, player_brio + gain)
	_update_bars()

func _animate_player_attack() -> void:
	var orig = player_node.position
	var tween = create_tween()
	tween.tween_property(player_node, "position:x", orig.x + 80, 0.1)
	tween.tween_property(player_node, "position:x", orig.x, 0.15)
	tween.tween_callback(_end_player_turn)

func _end_player_turn() -> void:
	if state == State.VICTORY or state == State.DEFEAT:
		return
	_check_victory()

func _check_victory() -> void:
	var all_dead = true
	for enemy in enemies:
		if enemy.vit > 0:
			all_dead = false
			break
	if all_dead:
		_on_victory()
		return
	_animate_player_idle()
	_start_enemy_phase()

func _on_victory() -> void:
	_set_state(State.VICTORY)
	turn_label.text = tr("combat_victory")
	var total_bits = 0
	for enemy in enemies:
		total_bits += enemy.data.bits_reward
	if GameManager.instance and GameManager.instance.run_data:
		GameManager.instance.run_data.vit_current = player_vit
		GameManager.instance.run_data.brio_current = player_brio
		var floor_done = GameManager.instance.on_combat_victory({"bits": total_bits, "enemies_defeated": enemies.size()})
		_log_message(tr("victory_bits_gained") % total_bits)
		await get_tree().create_timer(1.5).timeout
		if is_queued_for_deletion():
			return
		if floor_done:
			GameManager.instance.on_floor_completed()
		else:
			GameManager.instance.transition_to_map()
	else:
		_log_message(tr("victory_bits_gained") % total_bits)
		await get_tree().create_timer(1.5).timeout
		if is_queued_for_deletion():
			return
		GameManager.instance.transition_to_map()

func _on_defeat() -> void:
	_set_state(State.DEFEAT)
	turn_label.text = tr("combat_player_died")
	await get_tree().create_timer(1.5).timeout
	if is_queued_for_deletion():
		return
	GameManager.instance.on_combat_defeat()

func _start_enemy_phase() -> void:
	_set_state(State.ENEMY_TURN)

func _update_enemy_phase(delta: float) -> void:
	enemy_timer += delta
	if enemy_timer >= beat_interval:
		enemy_timer -= beat_interval
		enemy_phase_beats += 1
		_spawn_projectile()
		if enemy_phase_beats >= ENEMY_PHASE_LENGTH:
			_end_enemy_phase()
			return
	
	for p in projectiles:
		if p.hit:
			continue
		p.progress += _projectile_speed(p.pattern) * delta
		if p.progress >= 1.0:
			p.hit = true
			continue
		var px = _projectile_x(p.progress, p.pattern)
		var py = _lane_y(p.lane)
		p.sprite.position = Vector2(px, py)
		
		if px < _player_x() + 40 and p.lane == player_lane:
			p.hit_player = true
			p.hit = true
			_player_hit(p.damage)
	
	projectiles = projectiles.filter(func(p): return not p.hit)

func _projectile_speed(pattern: int) -> float:
	match pattern:
		ProjectilePattern.EASE_IN: return PROJ_SPEED_BASE * 0.5
		ProjectilePattern.EASE_OUT: return PROJ_SPEED_BASE * 1.5
		ProjectilePattern.MULTI: return PROJ_SPEED_BASE * 0.8
	return PROJ_SPEED_BASE

func _projectile_x(progress: float, pattern: int) -> float:
	var arena_w = arena_bg.size.x
	var p = progress
	match pattern:
		ProjectilePattern.EASE_IN:
			p = ease(progress, 0.4)
		ProjectilePattern.EASE_OUT:
			p = ease(progress, 2.5)
	return arena_bg.position.x + arena_w - p * arena_w

func _spawn_projectile() -> void:
	var pattern = randi() % 3
	var target_lane = randi() % lane_count
	var dmg = enemy_attack_power
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://visual/sprites/map/encounter.png")
	sprite.scale = Vector2(0.3, 0.3)
	sprite.position = Vector2(arena_bg.position.x + arena_bg.size.x, _lane_y(target_lane))
	proj_root.add_child(sprite)
	
	var proj = {
		pattern = pattern,
		lane = target_lane,
		progress = 0.0,
		sprite = sprite,
		hit = false,
		hit_player = false,
		damage = dmg
	}
	projectiles.append(proj)

func _player_hit(damage: int) -> void:
	if player_defending:
		damage = max(1, damage / 2)
		player_defending = false
	player_vit -= damage
	_update_bars()
	_log_message(tr("combat_damage_taken") % damage)
	_animate_player_hit()
	if player_vit <= 0:
		_on_defeat()

func _animate_player_hit() -> void:
	player_sprite.texture = preload("res://visual/sprites/mj/mj_hit.png")
	var tween = create_tween()
	tween.tween_property(player_sprite, "modulate", Color(1, 0.3, 0.3), 0.1)
	tween.tween_property(player_sprite, "modulate", Color(1, 1, 1), 0.15)
	tween.tween_callback(func():
		player_sprite.texture = preload("res://visual/sprites/mj/mj_idle_1.png")
	)

func _animate_player_idle() -> void:
	player_sprite.texture = preload("res://visual/sprites/mj/mj_idle_1.png")

func _end_enemy_phase() -> void:
	projectiles = []
	for child in proj_root.get_children():
		child.queue_free()
	if player_vit <= 0:
		return
	_set_state(State.PLAYER_ACTION_SELECT)

func _build_arena() -> void:
	var arena_w = 900
	var arena_h = min(500, lane_count * 80)
	arena_bg.size = Vector2(arena_w, arena_h)
	arena_bg.position = Vector2(960 - arena_w / 2, 540 - arena_h / 2)
	arena_bg.color = Color(0.08, 0.08, 0.12, 0.85)
	
	player_node.position = Vector2(_player_x(), _lane_y(player_lane))
	player_sprite.texture = preload("res://visual/sprites/mj/mj_idle_1.png")
	player_sprite.scale = Vector2(0.25, 0.25)
	_add_fill_sprite(player_node, player_sprite, "res://visual/sprites/mj/mj_idle_1_fill.png")
	
	var enemy_x = arena_bg.position.x + arena_w - 100
	for i in range(enemies.size()):
		var enemy = enemies[i]
		if not enemy.sprite:
			continue
		var lane_i = i % lane_count
		enemy.sprite.position = Vector2(enemy_x, _lane_y(lane_i))
		enemy_root.add_child(enemy.sprite)
	
	_build_lane_markers(arena_w, arena_h)
	
	lane_highlight.color = Color(1, 1, 1, 0.05)
	lane_highlight.size = Vector2(arena_w, _lane_height())
	_update_player_lane()

func _build_lane_markers(arena_w: float, arena_h: float) -> void:
	for child in lane_markers.get_children():
		child.queue_free()
	var lh = _lane_height()
	for i in range(1, lane_count):
		var line = ColorRect.new()
		line.size = Vector2(arena_w, 1)
		line.position = Vector2(arena_bg.position.x, arena_bg.position.y + i * lh)
		line.color = Color(1, 1, 1, 0.1)
		lane_markers.add_child(line)

func _create_enemy_instance(data, index: int) -> Dictionary:
	var tex_path = "res://visual/sprites/enemies/shronk.png"
	var sprite = Sprite2D.new()
	sprite.texture = load(tex_path)
	sprite.scale = Vector2(0.25, 0.25)
	
	var vit = data.vitality
	var bar = TextureProgressBar.new()
	bar.max_value = vit
	bar.value = vit
	bar.size = Vector2(80, 8)
	bar.position = Vector2(-40, -sprite.texture.get_height() * 0.25 - 10)
	bar.modulate = Color(0.8, 0.2, 0.2)
	sprite.add_child(bar)
	
	return {
		data = data,
		vit = vit,
		vit_max = vit,
		sprite = sprite,
		health_bar = bar,
		index = index
	}

func _update_enemy_bar(enemy) -> void:
	if enemy.health_bar:
		enemy.health_bar.value = max(0, enemy.vit)

func _player_x() -> float:
	return arena_bg.position.x + 100

func _lane_y(lane: int) -> float:
	return arena_bg.position.y + _lane_height() * lane + _lane_height() / 2

func _lane_height() -> float:
	return arena_bg.size.y / lane_count

func _update_player_lane() -> void:
	var target_y = _lane_y(player_lane)
	var tween = create_tween()
	tween.tween_property(player_node, "position:y", target_y, 0.1)
	lane_highlight.position = Vector2(arena_bg.position.x, arena_bg.position.y + player_lane * _lane_height())

func _update_bars() -> void:
	vit_bar.max_value = player_vit_max
	vit_bar.value = player_vit
	vit_label.text = tr("combat_vit_label") + ": " + str(player_vit) + "/" + str(player_vit_max)
	brio_bar.max_value = player_brio_max
	brio_bar.value = player_brio
	brio_label.text = tr("combat_brio_label") + ": " + str(player_brio) + "/" + str(player_brio_max)

func _log_message(msg: String) -> void:
	battle_log.text = msg
	var tween = create_tween()
	tween.tween_property(battle_log, "modulate:a", 1.0, 0.1)
	tween.tween_interval(1.5)
	tween.tween_property(battle_log, "modulate:a", 0.0, 0.5)

func _add_fill_sprite(parent: Node2D, main: Sprite2D, fill_path: String) -> void:
	var fill = Sprite2D.new()
	fill.texture = load(fill_path)
	fill.scale = main.scale
	if PaletteManager.instance:
		var pal = PaletteManager.instance.get_current_palette()
		fill.modulate = pal.color_2
	parent.add_child(fill)
	parent.move_child(fill, 0)
	if main.get_index() <= fill.get_index():
		parent.move_child(main, parent.get_child_count() - 1)

func _load_technique(id: int):
	var arr = load("res://data/techniques.tres")
	if arr and arr is Array:
		for t in arr:
			if t.id == id:
				return t
	return null

func _load_item(id: int):
	var arr = load("res://data/items.tres")
	if arr and arr is Array:
		for t in arr:
			if t.id == id:
				return t
	return null
