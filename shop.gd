extends CanvasLayer
class_name ShopScene

var shop_data: Resource = null
var catalog_items: Array = []
var catalog_techniques: Array = []
var catalog_upgrades: Array = []

@onready var shopkeeper = $Shopkeeper
@onready var speech_label = $SpeechLabel
@onready var bits_label = $BitsLabel
@onready var tab_container = $TabContainer
@onready var items_container = $TabContainer/Items/ScrollContainer/Grid
@onready var tech_container = $TabContainer/Techniques/ScrollContainer/Grid
@onready var upgrade_container = $TabContainer/Upgrades/ScrollContainer/Grid
@onready var back_btn = $BackBtn

func setup(data: Dictionary) -> void:
	var sd = data.get("shop_data", null)
	if sd:
		shop_data = sd
	else:
		shop_data = _pick_shop_tier()
	_populate_shop()

func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	_catalogs()

func _catalogs() -> void:
	var i = load("res://data/items.tres")
	if i is Array: catalog_items = i
	var t = load("res://data/techniques.tres")
	if t is Array: catalog_techniques = t
	var u = load("res://data/upgrades.tres")
	if u is Array: catalog_upgrades = u

func _pick_shop_tier():
	var arr = load("res://data/shops.tres")
	if arr is Array and arr.size() > 0:
		return arr[randi() % arr.size()]
	return null

func _populate_shop() -> void:
	if not shop_data:
		speech_label.text = tr("shop_welcome")
		return
	
	speech_label.text = tr(shop_data.welcome_key)
	shopkeeper.texture = preload("res://visual/sprites/shopkeeper/ven_shop.png")
	
	_populate_tab(items_container, shop_data.item_ids, "item")
	_populate_tab(tech_container, shop_data.technique_ids, "technique")
	_populate_tab(upgrade_container, shop_data.upgrade_ids, "upgrade")
	
	_update_bits()

func _populate_tab(container: Container, ids: Array, type: String) -> void:
	for child in container.get_children():
		child.queue_free()
	
	for id in ids:
		var entry = _create_entry(id, type)
		if entry:
			container.add_child(entry)

func _create_entry(id: int, type: String) -> Control:
	var catalog = _catalog_for_type(type)
	var data = _find_in_catalog(catalog, id)
	if not data:
		return null
	
	var entry = HBoxContainer.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_label = Label.new()
	match type:
		"item": name_label.text = data.get_item_name()
		"technique": name_label.text = data.get_technique_name()
		"upgrade": name_label.text = data.get_upgrade_name()
	name_label.theme_override_font_sizes/font_size = 18
	info.add_child(name_label)
	
	var desc_label = Label.new()
	if type == "technique":
		var t = data
		desc_label.text = tr("technique_inputs_label") + _format_inputs(t.inputs)
	else:
		var desc_key = data.get("description_key", "") if data.has("description_key") else ""
		desc_label.text = tr(desc_key) if desc_key else ""
	desc_label.theme_override_font_sizes/font_size = 14
	desc_label.modulate = Color(0.8, 0.8, 0.8)
	info.add_child(desc_label)
	
	var price_label = Label.new()
	price_label.text = tr("shop_bits_label") % data.price_bits
	price_label.theme_override_font_sizes/font_size = 14
	price_label.modulate = Color(0.9, 0.85, 0.5)
	info.add_child(price_label)
	
	entry.add_child(info)
	
	var buy_btn = Button.new()
	buy_btn.text = tr("shop_buy")
	var owned = _already_owned(id, type)
	buy_btn.disabled = owned
	if owned:
		buy_btn.text = tr("upgrade_already_owned")
	
	var rd = _run_data()
	if rd and rd.bits < data.price_bits:
		buy_btn.disabled = true
	
	buy_btn.pressed.connect(_on_buy.bind(data, type, buy_btn))
	entry.add_child(buy_btn)
	
	return entry

func _on_buy(data, type: String, btn: Button) -> void:
	var rd = _run_data()
	if not rd:
		return
	
	if not SaveManager.instance.spend_bits(rd, data.price_bits):
		return
	
	match type:
		"item":
			SaveManager.instance.add_item(rd, data.id)
		"technique":
			SaveManager.instance.add_technique(rd, data.id)
		"upgrade":
			SaveManager.instance.add_upgrade(rd, data.id)
	
	btn.disabled = true
	btn.text = tr("upgrade_already_owned")
	
	if type == "upgrade":
		GameManager.instance._check_palette_unlocks()
	
	_update_bits()
	_apply_upgrade_effects(data, type)
	
	speech_label.text = tr(shop_data.farewell_key)
	await get_tree().create_timer(1.5).timeout
	speech_label.text = tr(shop_data.welcome_key)

func _apply_upgrade_effects(data, type: String) -> void:
	if type != "upgrade":
		return
	if not data.is_incremental:
		return
	match data.incremental_type:
		0: _run_data().vit_max += data.incremental_intensity
		1: _run_data().brio_max += data.incremental_intensity

func _already_owned(id: int, type: String) -> bool:
	var rd = _run_data()
	if not rd:
		return false
	match type:
		"technique":
			return id in rd.techniques_owned
		"upgrade":
			return id in rd.upgrades_owned
	return false

func _catalog_for_type(type: String) -> Array:
	match type:
		"item": return catalog_items
		"technique": return catalog_techniques
		"upgrade": return catalog_upgrades
	return []

func _find_in_catalog(catalog: Array, id: int):
	for entry in catalog:
		if entry.id == id:
			return entry
	return null

func _format_inputs(inputs: Array) -> String:
	var parts = []
	for v in inputs:
		parts.append("●" if v == 1 else "○")
	return " ".join(parts)

func _update_bits() -> void:
	var rd = _run_data()
	bits_label.text = tr("shop_bits_label") % (rd.bits if rd else 0)

func _run_data():
	return GameManager.instance.run_data if GameManager.instance else null

func _on_back() -> void:
	if GameManager.instance:
		GameManager.instance.transition_to_map()
