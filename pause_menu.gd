extends CanvasLayer

@onready var menu = $MainMenu

func _ready() -> void:
	menu.setup_as_pause_menu()
	menu.resume_game.connect(_on_resume)
	menu.quit_game.connect(_on_quit)
	menu.open_settings.connect(_on_settings)

func _on_resume() -> void:
	GameManager.instance.resume_game()

func _on_quit() -> void:
	GameManager.instance.quit_to_menu()

func _on_settings() -> void:
	var settings = load("res://settings_menu.tscn").instantiate()
	add_child(settings)
