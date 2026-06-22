extends Control
class_name MainMenu

## MainMenu - Main menu and pause menu UI

@onready var vbox = $VBoxContainer
@onready var continue_btn = $VBoxContainer/ContinueButton
@onready var new_game_btn = $VBoxContainer/NewGameButton
@onready var settings_btn = $VBoxContainer/SettingsButton
@onready var quit_btn = $VBoxContainer/QuitButton

var is_pause_menu = false
var has_save_file = false

signal start_new_game
signal continue_game
signal open_settings
signal quit_game
signal resume_game

func _ready() -> void:
	_check_save_file()
	_setup_buttons()
	_update_continue_button()
	_update_texts()
	TranslationManager._language_changed.connect(_update_texts)

func _update_texts(_language := "") -> void:
	new_game_btn.text = tr("menu_new_game")
	settings_btn.text = tr("menu_settings")
	quit_btn.text = tr("menu_quit")
	if is_pause_menu:
		continue_btn.text = tr("pause_resume")
		quit_btn.text = tr("pause_quit")
	else:
		continue_btn.text = tr("menu_continue")

func _setup_buttons() -> void:
	new_game_btn.pressed.connect(_on_new_game_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func _check_save_file() -> void:
	var file = FileAccess.open("user://save.tres", FileAccess.READ)
	if file:
		has_save_file = true
		file.close()
	else:
		has_save_file = false

func _update_continue_button() -> void:
	continue_btn.disabled = not has_save_file
	if is_pause_menu:
		continue_btn.text = tr("pause_resume")
		if continue_btn.pressed.is_connected(_on_continue_pressed):
			continue_btn.pressed.disconnect(_on_continue_pressed)
		continue_btn.pressed.connect(_on_resume_pressed)
		new_game_btn.text = tr("menu_new_game")
		quit_btn.text = tr("pause_quit")

func setup_as_pause_menu() -> void:
	is_pause_menu = true
	_check_save_file()
	_update_continue_button()

func _on_new_game_pressed() -> void:
	start_new_game.emit()

func _on_continue_pressed() -> void:
	continue_game.emit()

func _on_resume_pressed() -> void:
	resume_game.emit()

func _on_settings_pressed() -> void:
	open_settings.emit()

func _on_quit_pressed() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = tr("pause_abandon_run") if is_pause_menu else tr("menu_confirm_quit")
	dialog.ok_button_text = tr("menu_yes")
	dialog.cancel_button_text = tr("menu_no")
	dialog.confirmed.connect(quit_game.emit)
	add_child(dialog)
	dialog.popup_centered()