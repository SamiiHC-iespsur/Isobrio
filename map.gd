extends CanvasLayer
class_name MapScene

@onready var floor_label = $HUD/FloorLabel
@onready var bits_label = $HUD/BitsLabel
@onready var map_root = $MapRoot

const SPACING_X = 180
const SPACING_Y = 100
const PATH_WIDTH = 2.5

const TEX_COMBAT = preload("res://visual/sprites/map/encounter.png")
const TEX_SHOP = preload("res://visual/sprites/map/shop.png")
const TEX_TREASURE = preload("res://visual/sprites/map/find.png")
const TEX_BOSS = preload("res://visual/sprites/map/end/eye_1.png")
const TEX_CURRENT = preload("res://visual/sprites/map/current.png")

func setup(_data: Dictionary = {}) -> void:
	_build_map()

func _build_map() -> void:
	_clear_map()
	var mm = MapManager.instance
	if not mm or mm.current_map.is_empty():
		return
	_draw_paths(mm)
	_place_nodes(mm)
	_place_marker(mm)
	_update_hud(mm)

func _clear_map() -> void:
	for child in map_root.get_children():
		child.queue_free()

func _start_x(mm: MapManager) -> float:
	return 960.0 - (mm.MAP_WIDTH - 1) * SPACING_X / 2.0

func _grid_to_screen(mm: MapManager, grid_x: int, grid_y: int) -> Vector2:
	return Vector2(
		_start_x(mm) + (mm.MAP_WIDTH - 1 - grid_y) * SPACING_X,
		100.0 + grid_x * SPACING_Y
	)

func _draw_paths(mm: MapManager) -> void:
	for x in range(mm.MAP_WIDTH):
		for y in range(mm.MAP_HEIGHT):
			var node = mm.current_map[x][y]
			if not node or node.node_type == MapNodeData.NodeType.REST:
				continue
			for conn in node.connected_nodes:
				var target = mm.current_map[conn.x][conn.y]
				if not target or target.node_type == MapNodeData.NodeType.REST:
					continue
				var line = Line2D.new()
				line.points = [
					_grid_to_screen(mm, x, y),
					_grid_to_screen(mm, conn.x, conn.y)
				]
				line.width = PATH_WIDTH
				line.default_color = Color(0.5, 0.6, 0.8, 0.4)
				line.antialiased = true
				map_root.add_child(line)

func _place_nodes(mm: MapManager) -> void:
	for x in range(mm.MAP_WIDTH):
		for y in range(mm.MAP_HEIGHT):
			var node = mm.current_map[x][y]
			if not node or node.node_type == MapNodeData.NodeType.REST:
				continue
			var tex = _texture_for_type(node.node_type)
			if not tex:
				continue
			var sprite = Sprite2D.new()
			sprite.texture = tex
			sprite.position = _grid_to_screen(mm, x, y)
			sprite.z_index = y
			_tint_node_sprite(sprite, node)
			if not node.hidden and node in mm.available_paths:
				_make_clickable(sprite, node)
			elif node.visited:
				sprite.modulate = Color(0.5, 0.5, 0.5, 0.5)
			else:
				sprite.modulate = Color(0.35, 0.35, 0.35, 0.5)
			map_root.add_child(sprite)

func _texture_for_type(node_type: int) -> Texture2D:
	match node_type:
		MapNodeData.NodeType.COMBAT:
			return TEX_COMBAT
		MapNodeData.NodeType.SHOP:
			return TEX_SHOP
		MapNodeData.NodeType.TREASURE:
			return TEX_TREASURE
		MapNodeData.NodeType.BOSS:
			return TEX_BOSS
	return null

func _make_clickable(sprite: Sprite2D, node: MapNodeData) -> void:
	var area = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	var tex_size = sprite.texture.get_size()
	shape.size = tex_size if tex_size != Vector2.ZERO else Vector2(32, 32)
	collision.shape = shape
	area.add_child(collision)
	area.input_event.connect(_on_node_clicked.bind(node))
	sprite.add_child(area)

func _on_node_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, node: MapNodeData) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if MapManager.instance.select_node(node):
			call_deferred("_on_node_selected", node)

func _on_node_selected(node: MapNodeData) -> void:
	match node.node_type:
		MapNodeData.NodeType.COMBAT:
			GameManager.instance.transition_to_combat(null, 1, false)
		MapNodeData.NodeType.BOSS:
			GameManager.instance.transition_to_combat(null, 1, true)
		MapNodeData.NodeType.SHOP:
			GameManager.instance.transition_to_shop(null)
		MapNodeData.NodeType.TREASURE:
			_award_treasure()

func _award_treasure() -> void:
	var gm = GameManager.instance
	if gm.run_data:
		var bits = randi_range(10, 50)
		gm.run_data.bits += bits
	MapManager.instance.complete_node()
	call_deferred("_check_floor_complete")

func _check_floor_complete() -> void:
	var mm = MapManager.instance
	if mm.current_node:
		var gx = int(mm.current_node.room_index / mm.MAP_HEIGHT)
		if gx == 0:
			call_deferred("_do_floor_complete")
			return
	GameManager.instance.transition_to_map()

func _do_floor_complete() -> void:
	GameManager.instance.on_floor_completed()

func _place_marker(mm: MapManager) -> void:
	if not mm.current_node:
		return
	var room_idx = mm.current_node.room_index
	var gx = int(room_idx / mm.MAP_HEIGHT)
	var gy = room_idx % mm.MAP_HEIGHT
	var marker = Sprite2D.new()
	marker.texture = TEX_CURRENT
	marker.position = _grid_to_screen(mm, gx, gy)
	marker.z_index = 100
	map_root.add_child(marker)

func _tint_node_sprite(sprite: Sprite2D, node: MapNodeData) -> void:
	var pm = PaletteManager.instance
	if not pm:
		return
	var pal = pm.get_current_palette()
	var idx = 1
	match node.node_type:
		MapNodeData.NodeType.SHOP: idx = 2
		MapNodeData.NodeType.TREASURE: idx = 2
		MapNodeData.NodeType.BOSS: idx = 0
	sprite.modulate = [pal.color_1, pal.color_2, pal.color_3][idx] if idx < 3 else Color.WHITE

func _update_hud(mm: MapManager) -> void:
	floor_label.text = tr("map_level") % mm.current_floor
	var rd = GameManager.instance.run_data if GameManager.instance else null
	bits_label.text = tr("map_bits") % (rd.bits if rd else 0)
