extends Resource
class_name ShopData

var welcome_key: String
var farewell_key: String
var item_ids: Array[int]
var upgrade_ids: Array[int]
var technique_ids: Array[int]

func get_welcome() -> String:
	return tr(welcome_key)

func get_farewell() -> String:
	return tr(farewell_key)
