extends Node

## MapManager - Handles procedural map generation and navigation

static var instance: MapManager

const MAP_WIDTH = 9
const MAP_HEIGHT = 9
const MAX_ROUTES = 5

signal map_generated
signal node_selected(node_data: MapNodeData)
signal floor_completed

var current_map: Array = []
var current_floor = 1
var current_node: MapNodeData = null
var available_paths: Array[MapNodeData] = []

func _init():
	instance = self

func generate_map(seed_val: int, floor: int = 1) -> void:
	if seed_val != 0:
		seed(seed_val)
	else:
		randomize()
	
	current_floor = floor
	current_map = []
	
	# Create empty grid
	for x in range(MAP_WIDTH):
		var column = []
		for y in range(MAP_HEIGHT):
			column.append(null)
		current_map.append(column)
	
	# Generate nodes for this floor
	_generate_floor_nodes(floor)
	_connect_nodes()
	
	# Set starting node (bottom center)
	current_node = current_map[int(MAP_WIDTH / 2)][MAP_HEIGHT - 1]
	current_node.visited = true
	_calculate_available_paths()
	
	map_generated.emit()

func _generate_floor_nodes(floor: int) -> void:
	var node_types = [MapNodeData.NodeType.COMBAT, MapNodeData.NodeType.SHOP, 
					  MapNodeData.NodeType.TREASURE, MapNodeData.NodeType.REST]
	
	# Ensure at least one shop and one treasure per floor
	var shop_placed = false
	var treasure_placed = false
	
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			# Skip some positions for path variety
			if randi() % 3 == 0 and not (x == int(MAP_WIDTH / 2) and y == MAP_HEIGHT - 1):
				continue
			
			var node = MapNodeData.new()
			node.floor_index = floor
			node.room_index = x * MAP_HEIGHT + y
			node.route_index = randi() % MAX_ROUTES
			
			# Special nodes
			if y == 0 and floor % 3 == 0:  # Boss every 3 floors
				node.node_type = MapNodeData.NodeType.BOSS
			elif y == 0:
				node.node_type = MapNodeData.NodeType.COMBAT
			elif not shop_placed and randi() % 4 == 0:
				node.node_type = MapNodeData.NodeType.SHOP
				shop_placed = true
			elif not treasure_placed and randi() % 4 == 0:
				node.node_type = MapNodeData.NodeType.TREASURE
				treasure_placed = true
			else:
				node.node_type = node_types[randi() % node_types.size()]
			
			# Hidden nodes (secret paths)
			if randi() % 10 == 0:
				node.hidden = true
			
			current_map[x][y] = node

func _connect_nodes() -> void:
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var node = current_map[x][y]
			if not node:
				continue
			
			var connections = []
			
			# Connect to nodes in next row (y-1)
			if y > 0:
				for dx in [-1, 0, 1]:
					var nx = x + dx
					if nx >= 0 and nx < MAP_WIDTH:
						var target = current_map[nx][y - 1]
						if target:
							connections.append(Vector2i(nx, y - 1))
			
			node.connected_nodes = connections

func _calculate_available_paths() -> void:
	available_paths = []
	if not current_node:
		return
	
	for conn in current_node.connected_nodes:
		var target = current_map[conn.x][conn.y]
		if target and not target.visited:
			available_paths.append(target)

func select_node(node: MapNodeData) -> bool:
	if node in available_paths:
		current_node.visited = true
		current_node = node
		current_node.visited = true
		_calculate_available_paths()
		node_selected.emit(node)
		return true
	return false

func get_node_at_grid_pos(grid_pos: Vector2i) -> MapNodeData:
	if grid_pos.x >= 0 and grid_pos.x < MAP_WIDTH and grid_pos.y >= 0 and grid_pos.y < MAP_HEIGHT:
		return current_map[grid_pos.x][grid_pos.y]
	return null

func get_current_node_screen_pos() -> Vector2:
	# Convert grid position to screen position
	var spacing_x = 180
	var spacing_y = 100
	var start_x = 960 - (MAP_WIDTH - 1) * spacing_x / 2
	var start_y = 100
	return Vector2(start_x + (MAP_WIDTH - 1 - current_node.room_index % MAP_WIDTH) * spacing_x, 
				   start_y + int(current_node.room_index  /  MAP_WIDTH) * spacing_y)

func get_available_paths_screen_pos() -> Array[Vector2]:
	var positions = []
	var spacing_x = 180
	var spacing_y = 100
	var start_x = 960 - (MAP_WIDTH - 1) * spacing_x / 2
	var start_y = 100
	
	for node in available_paths:
		var x = start_x + (MAP_WIDTH - 1 - node.room_index % MAP_WIDTH) * spacing_x
		var y = start_y + int(node.room_index  /  MAP_WIDTH) * spacing_y
		positions.append(Vector2(x, y))
	return positions

func complete_node() -> void:
	if int(current_node.room_index  /  MAP_WIDTH) == 0:  # Reached top
		floor_completed.emit()
