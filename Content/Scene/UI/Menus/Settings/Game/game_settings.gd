extends Control

func _on_language_config_changed(value: Variant) -> void:
	SettingsManager.set_locale_by_lang(value as LocalizationUtils.Lang)
