extends Node

## TranslationManager - Handles language switching and persistence

static var instance: TranslationManager

var current_language: String = "en"
var available_languages: Array[String] = ["en", "es"]
var language_names: Dictionary = {
	"en": "English",
	"es": "Español"
}

const CONFIG_PATH = "user://config.tres"

func _init():
	instance = self
	_load_csv_translations()
	_load_language()

func _load_csv_translations() -> void:
	for lang in available_languages:
		var path = "res://translations/%s.csv" % lang
		var file = FileAccess.open(path, FileAccess.READ)
		if not file:
			continue
		var t := Translation.new()
		t.locale = lang
		var header = file.get_csv_line()
		if header.is_empty() or header[0] != "keys":
			continue
		while not file.eof_reached():
			var line = file.get_csv_line()
			if line.is_empty() or line[0].begins_with("#"):
				continue
			if line.size() >= 2 and not line[0].is_empty():
				t.add_message(line[0], line[1])
		TranslationServer.add_translation(t)

func _load_language() -> void:
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		current_language = config.get_value("settings", "language", "en")
	_set_language(current_language)

func _save_language() -> void:
	var config = ConfigFile.new()
	config.set_value("settings", "language", current_language)
	config.save(CONFIG_PATH)

func _set_language(lang: String) -> void:
	if lang in available_languages:
		current_language = lang
		TranslationServer.set_locale(lang)
		_save_language()
		_language_changed.emit(lang)

signal _language_changed(language: String)

func get_language_name(code: String) -> String:
	return language_names.get(code, code)

func get_current_language_name() -> String:
	return get_language_name(current_language)

func set_language(lang: String) -> void:
	if lang != current_language:
		_set_language(lang)

func get_available_languages() -> Array[Dictionary]:
	var result = []
	for lang in available_languages:
		result.append({"code": lang, "name": language_names[lang]})
	return result

func translate_message(key: StringName, args: Array = []) -> String:
	var translated = TranslationServer.translate(key, "")
	if not args.is_empty():
		translated = translated % args
	return translated
