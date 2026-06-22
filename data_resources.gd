extends Resource
class_name GameData

## Data Resources for Items, Techniques, Upgrades, Enemies

class ItemData extends Resource:
	@export var id: int
	@export var name_key: String
	@export var description_key: String
	@export var comment_key: String
	@export var type: ItemType
	@export var intensity: int
	@export var price_bits: int
	
	enum ItemType { RHYTHM, VIT, BRIO }
	
	func get_item_name() -> String: return tr(name_key)
	func get_description() -> String: return tr(description_key)
	func get_comment() -> String: return tr(comment_key)
	func get_type_name() -> String:
		match type:
			ItemType.RHYTHM: return tr("item_type_rhythm")
			ItemType.VIT: return tr("item_type_vit")
			ItemType.BRIO: return tr("item_type_brio")
		return ""

class TechniqueData extends Resource:
	@export var id: int
	@export var name_key: String
	@export var type: TechniqueType
	@export var power: int
	@export var inputs: Array[int]
	@export var price_bits: int
	@export var brio_cost: int
	
	enum TechniqueType { RHYTHM, ATTACK, MULTI_ATTACK, HEAL }
	
	func get_technique_name() -> String: return tr(name_key)
	func get_type_name() -> String:
		match type:
			TechniqueType.RHYTHM: return tr("technique_type_rhythm")
			TechniqueType.ATTACK: return tr("technique_type_attack")
			TechniqueType.MULTI_ATTACK: return tr("technique_type_multi_attack")
			TechniqueType.HEAL: return tr("technique_type_heal")
		return ""

class UpgradeData extends Resource:
	@export var id: int
	@export var name_key: String
	@export var description_key: String
	@export var comment_key: String
	@export var price_bits: int
	@export var is_incremental: bool
	@export var incremental_type: IncrementalType
	@export var incremental_intensity: int
	@export var advanced_effect: Dictionary
	
	enum IncrementalType { MAX_VIT, MAX_BRIO, ATTACK, DEFENSE, ITEM_DROP_RATE, INPUT_WINDOW, BITS_REWARD }
	
	func get_upgrade_name() -> String: return tr(name_key)
	func get_description() -> String: return tr(description_key)
	func get_comment() -> String: return tr(comment_key)
	func get_type_name() -> String:
		match incremental_type:
			IncrementalType.MAX_VIT: return tr("upgrade_type_max_vit")
			IncrementalType.MAX_BRIO: return tr("upgrade_type_max_brio")
			IncrementalType.ATTACK: return tr("upgrade_type_attack")
			IncrementalType.DEFENSE: return tr("upgrade_type_defense")
			IncrementalType.ITEM_DROP_RATE: return tr("upgrade_type_item_drop_rate")
			IncrementalType.INPUT_WINDOW: return tr("upgrade_type_input_window")
			IncrementalType.BITS_REWARD: return tr("upgrade_type_bits_reward")
		return ""
