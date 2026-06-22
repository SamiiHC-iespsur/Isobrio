extends Resource
class_name EnemyData

var id: int
var is_boss: bool
var name_key: String
var vitality: int
var bits_reward: int
var reward_item_id: int
var reward_item_prob: int
var boss_reward_upgrade_id: int

func get_enemy_name() -> String:
	return tr(name_key)
