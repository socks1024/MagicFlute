@tool
class_name InputContext
extends Resource
## 输入上下文资源类，描述一组应当同时激活的 InputAction

## 上下文的唯一标识名称（如 &"gameplay"、&"dialogue"）
@export var context_name: StringName = &""

## 是否在 actions 下拉枚举中显示 Godot 内置的 ui_ Action（默认隐藏）
@export var include_ui_actions: bool = false:
	set(value):
		include_ui_actions = value
		notify_property_list_changed()

## 该上下文包含的 InputAction 名称列表（在编辑器中以原生数组形式展示，每项为下拉枚举）
var actions: Array[StringName] = []

func _get_property_list() -> Array[Dictionary]:
	# 从 ProjectSettings 读取 input/ 分组下的 Action
	# 根据 include_ui_actions 决定是否包含 ui_ 内置 Action
	var enum_values: PackedStringArray = []
	for prop in ProjectSettings.get_property_list():
		var prop_name: String = prop["name"]
		if prop_name.begins_with("input/"):
			var action_name: String = prop_name.substr(6) # 去掉 "input/" 前缀
			if include_ui_actions or not action_name.begins_with("ui_"):
				enum_values.append(action_name)
	var hint_string: String = ",".join(enum_values)

	return [{
		"name": "actions",
		"type": TYPE_ARRAY,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_TYPE_STRING,
		# 格式：元素类型ID/hint类型:hint_string
		# TYPE_STRING_NAME = 21
		"hint_string": "%d/%d:%s" % [TYPE_STRING_NAME, PROPERTY_HINT_ENUM, hint_string],
	}]

func _get(property: StringName) -> Variant:
	if property == &"actions":
		return actions
	return null

func _set(property: StringName, value: Variant) -> bool:
	if property == &"actions":
		actions = value
		return true
	return false
