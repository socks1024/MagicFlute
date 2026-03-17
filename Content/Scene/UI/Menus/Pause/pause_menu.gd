extends Control

signal resume_game
signal back_to_start
signal goto_settings
signal show_help

## 暂停菜单的主容器，用于在显示子菜单时隐藏
@onready var main_panel: Panel = $MainPanel

## 内嵌的设置菜单
@onready var settings_menu: Control = $SettingsMenu

## 内嵌的游戏说明面板
@onready var help_panel: Panel = $HelpPanel


func _ready() -> void:
	_show_main_panel()


## 显示暂停菜单主面板
func _show_main_panel() -> void:
	main_panel.show()
	settings_menu.hide()
	help_panel.hide()


## 继续游戏
func _on_resume_anim_finish() -> void:
	resume_game.emit()


## 返回主菜单
func _on_back_to_start_anim_finish() -> void:
	back_to_start.emit()


## 打开设置
func _on_settings_anim_finish() -> void:
	main_panel.hide()
	settings_menu.show()


## 查看游戏说明
func _on_help_anim_finish() -> void:
	main_panel.hide()
	help_panel.show()


## 从设置菜单返回暂停菜单
func _on_settings_back() -> void:
	_show_main_panel()


## 从游戏说明返回暂停菜单
func _on_help_back_anim_finish() -> void:
	_show_main_panel()
