class_name LocalizationUtils

enum Lang{
	ENG,
	ZHS,
}

const LANG_LOCALE: Dictionary = {
	LocalizationUtils.Lang.ENG: "en",
	LocalizationUtils.Lang.ZHS: "zh",
}

## 获取默认语言
static func get_default_lang() -> Lang:
	return get_lang_by_locale(OS.get_locale())

## 根据本地化代码获取语言
static func get_lang_by_locale(locale:String) -> Lang:
	var short_locale := locale.split("_")[0]
	for lang in LANG_LOCALE:
		if LANG_LOCALE[lang] == short_locale:
			return lang
	return LocalizationUtils.Lang.ENG

## 根据语言获取本地化代码
static func get_locale_by_lang(lang:Lang) -> String:
	return LANG_LOCALE.get(lang, "en")
