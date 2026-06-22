extends Resource
class_name MapNodeData

var floor_index: int
var room_index: int
var route_index: int
var node_type: NodeType
var hidden: bool = false
var visited: bool = false
var connected_nodes: Array[Vector2i]

enum NodeType { COMBAT, SHOP, TREASURE, BOSS, REST }

func get_type_name() -> String:
	match node_type:
		NodeType.COMBAT: return tr("map_node_combat")
		NodeType.SHOP: return tr("map_node_shop")
		NodeType.TREASURE: return tr("map_node_treasure")
		NodeType.BOSS: return tr("map_node_boss")
		NodeType.REST: return tr("map_node_rest")
	return ""
