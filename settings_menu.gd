extends Control
class_name SettingsMenu

## SettingsMenu - Game settings UI

@onready var tab_container = $TabContainer
@onready var audio_tab = $TabContainer/AudioTab/Content
@onready var video_tab = $TabContainer/VideoTab/Content
@onready var accessibility_tab = $TabContainer/AccessibilityTab/Content
@onready var language_tab = $TabContainer/LanguageTab/Content
@onready var palette_tab = $TabContainer/PaletteTab/Content
@onready var close_btn = $CloseButton

var config: GameConfig

signal settings_changed

func _ready() -> void:
	config = GameConfig.load()
	TranslationManager._language_changed.connect(_refresh_translations)
	_setup_audio_tab()
	_setup_video_tab()
	_setup_accessibility_tab()
	_setup_language_tab()
	_setup_palette_tab()
	close_btn.text = tr("settings_close")
	close_btn.pressed.connect(_on_close_pressed)

func _refresh_translations(_language := "") -> void:
	audio_tab.get_node("MasterSliderRow/MasterLabel").text = tr("settings_master_volume_label")
	audio_tab.get_node("SFXSliderRow/SFXLabel").text = tr("settings_sfx_volume_label")
	audio_tab.get_node("MusicSliderRow/MusicLabel").text = tr("settings_music_volume_label")
	audio_tab.get_node("MetronomeRow/MetronomeLabel").text = tr("settings_metronome_label")
	video_tab.get_node("FullscreenRow/FullscreenLabel").text = tr("settings_fullscreen_label")
	video_tab.get_node("FullscreenRow/FullscreenCheck").text = tr("settings_on") if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else tr("settings_off")
	video_tab.get_node("VSyncRow/VSyncLabel").text = tr("settings_vsync_label")
	accessibility_tab.get_node("VisualAssistRow/VisualAssistLabel").text = tr("settings_visual_assist_label")
	accessibility_tab.get_node("ReducedMotionRow/ReducedMotionLabel").text = tr("settings_reduced_motion_label")
	language_tab.get_node("LanguageRow/LanguageLabel").text = tr("settings_language_label")
	var lang_dropdown = language_tab.get_node("LanguageRow/LanguageDropdown")
	lang_dropdown.clear()
	lang_dropdown.add_item(tr("lang_english"))
	lang_dropdown.add_item(tr("lang_spanish"))
	lang_dropdown.selected = 0 if config.language == "en" else 1
	palette_tab.get_node("PaletteLabel").text = tr("settings_palette_label")
	close_btn.text = tr("settings_close")

func _setup_audio_tab() -> void:
	audio_tab.get_node("MasterSliderRow/MasterLabel").text = tr("settings_master_volume_label")
	audio_tab.get_node("SFXSliderRow/SFXLabel").text = tr("settings_sfx_volume_label")
	audio_tab.get_node("MusicSliderRow/MusicLabel").text = tr("settings_music_volume_label")
	audio_tab.get_node("MetronomeRow/MetronomeLabel").text = tr("settings_metronome_label")

	var master_slider = audio_tab.get_node("MasterSliderRow/MasterSlider")
	var sfx_slider = audio_tab.get_node("SFXSliderRow/SFXSlider")
	var music_slider = audio_tab.get_node("MusicSliderRow/MusicSlider")
	var metronome_check = audio_tab.get_node("MetronomeRow/MetronomeCheck")
	var metronome_slider = audio_tab.get_node("MetronomeRow/MetronomeSlider")

	master_slider.value = config.master_volume
	sfx_slider.value = config.sfx_volume
	music_slider.value = config.music_volume
	metronome_check.button_pressed = config.metronome_enabled
	metronome_slider.value = config.metronome_volume
	metronome_slider.editable = config.metronome_enabled

	master_slider.value_changed.connect(_on_master_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	metronome_check.toggled.connect(_on_metronome_toggled)
	metronome_slider.value_changed.connect(_on_metronome_volume_changed)

func _setup_video_tab() -> void:
	var fullscreen_label = video_tab.get_node("FullscreenRow/FullscreenLabel")
	var vsync_label = video_tab.get_node("VSyncRow/VSyncLabel")

	fullscreen_label.text = tr("settings_fullscreen_label")
	vsync_label.text = tr("settings_vsync_label")

	var mode = DisplayServer.window_get_mode()
	video_tab.get_node("FullscreenRow/FullscreenCheck").text = tr("settings_on") if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else tr("settings_off")
	video_tab.get_node("VSyncRow/VSyncCheck").button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED

	video_tab.get_node("FullscreenRow").gui_input.connect(_on_fullscreen_gui_input)
	video_tab.get_node("VSyncRow/VSyncCheck").toggled.connect(_on_vsync_toggled)

func _setup_accessibility_tab() -> void:
	var visual_assist_label = accessibility_tab.get_node("VisualAssistRow/VisualAssistLabel")
	var reduced_motion_label = accessibility_tab.get_node("ReducedMotionRow/ReducedMotionLabel")

	visual_assist_label.text = tr("settings_visual_assist_label")
	reduced_motion_label.text = tr("settings_reduced_motion_label")

	accessibility_tab.get_node("VisualAssistRow/VisualAssistCheck").button_pressed = config.visual_assist
	accessibility_tab.get_node("ReducedMotionRow/ReducedMotionCheck").button_pressed = config.reduced_motion

	accessibility_tab.get_node("VisualAssistRow/VisualAssistCheck").toggled.connect(_on_visual_assist_toggled)
	accessibility_tab.get_node("ReducedMotionRow/ReducedMotionCheck").toggled.connect(_on_reduced_motion_toggled)

func _setup_language_tab() -> void:
	var lang_label = language_tab.get_node("LanguageRow/LanguageLabel")
	lang_label.text = tr("settings_language_label")
	var lang_dropdown = language_tab.get_node("LanguageRow/LanguageDropdown")
	lang_dropdown.add_item(tr("lang_english"))
	lang_dropdown.add_item(tr("lang_spanish"))
	lang_dropdown.selected = 0 if config.language == "en" else 1
	lang_dropdown.item_selected.connect(_on_language_selected)

func _setup_palette_tab() -> void:
	var palette_label = palette_tab.get_node("PaletteLabel")
	palette_label.text = tr("settings_palette_label")
	var palette_container = palette_tab.get_node("PaletteContainer")
	var palette_manager = PaletteManager.instance

	for child in palette_container.get_children():
		palette_container.remove_child(child)
		child.queue_free()

	for palette in palette_manager.palettes:
		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(200, 50)
		btn.texture_normal = _create_palette_preview(palette)
		btn.tooltip_text = "%s\n%s" % [palette.palette_name, palette.unlock_condition] if not palette.unlocked else palette.palette_name
		btn.disabled = not palette.unlocked
		btn.pressed.connect(_on_palette_selected.bind(palette.palette_id))
		palette_container.add_child(btn)

func _create_palette_preview(palette: ColorPalette) -> Texture2D:
	var img = Image.create(200, 50, false, Image.FORMAT_RGBA8)
	img.fill(palette.color_1)
	img.fill_rect(Rect2(66, 0, 68, 50), palette.color_2)
	img.fill_rect(Rect2(134, 0, 66, 50), palette.color_3)
	var tex = ImageTexture.create_from_image(img)
	return tex

func _on_master_volume_changed(value: float) -> void:
	config.master_volume = int(value)
	config.apply_audio_settings()
	settings_changed.emit()

func _on_sfx_volume_changed(value: float) -> void:
	config.sfx_volume = int(value)
	config.apply_audio_settings()
	settings_changed.emit()

func _on_music_volume_changed(value: float) -> void:
	config.music_volume = int(value)
	config.apply_audio_settings()
	settings_changed.emit()

func _on_metronome_toggled(pressed: bool) -> void:
	config.metronome_enabled = pressed
	config.save()
	var metronome_slider = audio_tab.get_node("MetronomeRow/MetronomeSlider")
	metronome_slider.editable = pressed
	settings_changed.emit()

func _on_metronome_volume_changed(value: float) -> void:
	config.metronome_volume = int(value)
	config.save()
	settings_changed.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var fs_row = video_tab.get_node("FullscreenRow")
		var rect = Rect2(fs_row.get_global_rect().position, fs_row.get_global_rect().size)
		if rect.has_point(event.global_position):
			_toggle_fullscreen()
			get_viewport().set_input_as_handled()

func _on_fullscreen_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_fullscreen()

func _toggle_fullscreen() -> void:
	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	video_tab.get_node("FullscreenRow/FullscreenCheck").text = tr("settings_on") if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else tr("settings_off")

func _on_vsync_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_visual_assist_toggled(pressed: bool) -> void:
	config.visual_assist = pressed
	config.save()
	settings_changed.emit()

func _on_reduced_motion_toggled(pressed: bool) -> void:
	config.reduced_motion = pressed
	config.save()
	settings_changed.emit()

func _on_language_selected(index: int) -> void:
	var new_lang = "en" if index == 0 else "es"
	if new_lang != config.language:
		config.language = new_lang
		config.save()
		TranslationManager.instance.set_language(new_lang)
		_refresh_translations()
		settings_changed.emit()

func _on_palette_selected(id: int) -> void:
	if PaletteManager.instance.set_palette(id):
		_setup_palette_tab()
		settings_changed.emit()

func _on_close_pressed() -> void:
	queue_free()
