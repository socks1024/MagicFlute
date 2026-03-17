@tool
@abstract class_name PostProcessControllerBase
extends Node

## 后处理控制器抽象基类。
## 自动扫描子节点上的 ShaderMaterial，生成检查器面板，
## 并统一管理效果开关与 shader 参数回写。
## 子类需要实现 4 个抽象方法以适配不同节点类型。

const BINDING_KIND_ENABLED: String = "enabled"
const BINDING_KIND_PARAM: String = "param"
const SCREEN_TEXTURE_PARAM: String = "SCREEN_TEXTURE"
const SHADER_PARAMETER_PREFIX: String = "shader_parameter/"

## 效果列表：[{ "name": 节点名, "params": [{ "shader_param": uniform名, "type": 类型, "hint": hint, "hint_string": hint_string, "default": 默认值 }] }]
var _effects: Array[Dictionary] = []

## 属性绑定表：{ "检查器属性名": { "kind": 类型, "effect": 效果名, "shader_param": 参数名, "default": 默认值 } }
var _property_bindings: Dictionary = {}

## 运行时参数值：{ "节点名/shader_param": 值 }
var _param_values: Dictionary = {}

## 运行时启用状态：{ "节点名": bool }
var _enabled_states: Dictionary = {}


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_CHILD_ORDER_CHANGED:
			_scan_effects()
			notify_property_list_changed()


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	for effect_data in _effects:
		var effect: Dictionary = effect_data
		_apply_effect(effect, true)


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	for effect_data in _effects:
		var effect: Dictionary = effect_data
		var effect_name: String = str(effect["name"])

		properties.append({
			"name": effect_name,
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP,
		})

		properties.append({
			"name": _get_enabled_property_name(effect_name),
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
		})

		for param_data in effect["params"]:
			var param: Dictionary = param_data
			var shader_param: String = str(param["shader_param"])
			var property_info: Dictionary = {
				"name": _get_param_property_name(effect_name, shader_param),
				"type": param["type"],
				"usage": PROPERTY_USAGE_DEFAULT,
			}

			if int(param["type"]) == TYPE_OBJECT:
				property_info["hint"] = PROPERTY_HINT_RESOURCE_TYPE
				property_info["hint_string"] = "Texture2D"
			else:
				if int(param["hint"]) != PROPERTY_HINT_NONE:
					property_info["hint"] = param["hint"]
				if str(param["hint_string"]) != "":
					property_info["hint_string"] = param["hint_string"]

			properties.append(property_info)

	return properties


func _set(property: StringName, value: Variant) -> bool:
	var binding: Dictionary = _get_property_binding(property)
	if binding.is_empty():
		return false

	var effect_name: String = str(binding["effect"])
	var kind: String = str(binding["kind"])

	if kind == BINDING_KIND_ENABLED:
		_enabled_states[effect_name] = value
		_apply_effect_enabled(effect_name)
		return true

	var shader_param: String = str(binding["shader_param"])
	var param_key: String = _get_param_key(effect_name, shader_param)
	_param_values[param_key] = value
	_apply_effect_param(effect_name, shader_param, binding["default"])
	return true


func _get(property: StringName) -> Variant:
	var binding: Dictionary = _get_property_binding(property)
	if binding.is_empty():
		return null

	var effect_name: String = str(binding["effect"])
	var kind: String = str(binding["kind"])
	var default_value: Variant = binding["default"]

	if kind == BINDING_KIND_ENABLED:
		return _enabled_states.get(effect_name, default_value)

	var shader_param: String = str(binding["shader_param"])
	var param_key: String = _get_param_key(effect_name, shader_param)
	return _param_values.get(param_key, default_value)


func _property_can_revert(property: StringName) -> bool:
	var binding: Dictionary = _get_property_binding(property)
	if binding.is_empty():
		return false

	var effect_name: String = str(binding["effect"])
	var kind: String = str(binding["kind"])
	var default_value: Variant = binding["default"]

	if kind == BINDING_KIND_ENABLED:
		return _enabled_states.get(effect_name, default_value) != default_value

	var shader_param: String = str(binding["shader_param"])
	var param_key: String = _get_param_key(effect_name, shader_param)
	var current_value: Variant = _param_values.get(param_key, default_value)
	return current_value != default_value


func _property_get_revert(property: StringName) -> Variant:
	var binding: Dictionary = _get_property_binding(property)
	if binding.is_empty():
		return null

	return binding["default"]


## 启用所有后处理效果。
func enable_all() -> void:
	for effect_data in _effects:
		var effect: Dictionary = effect_data
		set(_get_enabled_property_name(str(effect["name"])), true)


## 禁用所有后处理效果。
func disable_all() -> void:
	for effect_data in _effects:
		var effect: Dictionary = effect_data
		set(_get_enabled_property_name(str(effect["name"])), false)


## 启用指定效果。
func enable_effect(effect_name: String) -> void:
	set(_get_enabled_property_name(effect_name), true)


## 禁用指定效果。
func disable_effect(effect_name: String) -> void:
	set(_get_enabled_property_name(effect_name), false)


## 获取指定效果的 ShaderMaterial。
func get_effect_material(effect_name: String) -> ShaderMaterial:
	var material: ShaderMaterial = _get_effect_material_by_name(effect_name)
	if material != null:
		return material

	CLog.w("PostProcess: 未知的效果名称 '%s'" % effect_name)
	return null


## 设置指定效果的 shader 参数。
func set_effect_param(effect_name: String, shader_param: String, value: Variant) -> void:
	set(_get_param_property_name(effect_name, shader_param), value)


## 获取指定效果的 shader 参数。
func get_effect_param(effect_name: String, shader_param: String) -> Variant:
	return get(_get_param_property_name(effect_name, shader_param))


## 获取所有效果名列表。
func get_effect_names() -> Array[String]:
	var names: Array[String] = []

	for effect_data in _effects:
		var effect: Dictionary = effect_data
		names.append(str(effect["name"]))

	return names


## 恢复指定效果的单个参数到默认值。
func reset_effect_param(effect_name: String, shader_param: String) -> void:
	var property_name: String = _get_param_property_name(effect_name, shader_param)
	var binding: Dictionary = _property_bindings.get(property_name, {})
	if binding.is_empty():
		CLog.w("PostProcess: 未找到效果 '%s' 或参数 '%s'" % [effect_name, shader_param])
		return

	var default_value: Variant = binding["default"]
	var param_key: String = _get_param_key(effect_name, shader_param)
	_param_values[param_key] = default_value
	_apply_effect_param(effect_name, shader_param, default_value)
	notify_property_list_changed()


## 恢复指定效果的所有参数到默认值。
func reset_effect_params(effect_name: String) -> void:
	var target_effect: Dictionary = {}

	for effect_data in _effects:
		var effect: Dictionary = effect_data
		if str(effect["name"]) == effect_name:
			target_effect = effect
			break

	if target_effect.is_empty():
		CLog.w("PostProcess: 未找到效果 '%s'" % effect_name)
		return

	for param_data in target_effect["params"]:
		var param: Dictionary = param_data
		var shader_param: String = str(param["shader_param"])
		var default_value: Variant = param["default"]
		var param_key: String = _get_param_key(effect_name, shader_param)
		_param_values[param_key] = default_value
		_apply_effect_param(effect_name, shader_param, default_value)

	notify_property_list_changed()


## 恢复所有效果的所有参数到默认值。
func reset_all_params() -> void:
	for effect_data in _effects:
		var effect: Dictionary = effect_data
		var effect_name: String = str(effect["name"])

		for param_data in effect["params"]:
			var param: Dictionary = param_data
			var shader_param: String = str(param["shader_param"])
			var default_value: Variant = param["default"]
			var param_key: String = _get_param_key(effect_name, shader_param)
			_param_values[param_key] = default_value
			_apply_effect_param(effect_name, shader_param, default_value)

	notify_property_list_changed()


# ── 子类必须实现的抽象方法 ─────────────────────────────────────────────


## 返回所有可用作后处理效果的子节点列表。
@abstract func _get_effect_children() -> Array[Node];

## 从效果子节点上获取 ShaderMaterial。
@abstract func _get_shader_material(node: Node) -> ShaderMaterial;

## 根据效果名获取对应的子节点。
@abstract func _get_effect_node_by_name(effect_name: String) -> Node;

## 设置效果子节点的可见性。
@abstract func _set_effect_node_visible(node: Node, visible: bool) -> void;


# ── 内部方法 ──────────────────────────────────────────────────────────


func _scan_effects() -> void:
	_effects.clear()
	_property_bindings.clear()

	for child in _get_effect_children():
		var material: ShaderMaterial = _get_shader_material(child)
		if material == null or material.shader == null:
			continue

		var effect_name: String = child.name
		var params: Array[Dictionary] = []

		_property_bindings[_get_enabled_property_name(effect_name)] = {
			"kind": BINDING_KIND_ENABLED,
			"effect": effect_name,
			"default": false,
		}

		for property_data in material.get_property_list():
			var property_info: Dictionary = property_data
			var property_name: String = str(property_info.get("name", ""))
			if not property_name.begins_with(SHADER_PARAMETER_PREFIX):
				continue

			var shader_param: String = property_name.trim_prefix(SHADER_PARAMETER_PREFIX)
			if _should_ignore_param(shader_param):
				continue

			var default_value: Variant = material.get_shader_parameter(shader_param)
			var param_info: Dictionary = {
				"shader_param": shader_param,
				"type": property_info.get("type", TYPE_FLOAT),
				"hint": property_info.get("hint", PROPERTY_HINT_NONE),
				"hint_string": property_info.get("hint_string", ""),
				"default": default_value,
			}
			params.append(param_info)

			var param_key: String = _get_param_key(effect_name, shader_param)
			if not _param_values.has(param_key):
				_param_values[param_key] = default_value

			_property_bindings[_get_param_property_name(effect_name, shader_param)] = {
				"kind": BINDING_KIND_PARAM,
				"effect": effect_name,
				"shader_param": shader_param,
				"default": default_value,
			}

		if not _enabled_states.has(effect_name):
			_enabled_states[effect_name] = false

		_effects.append({
			"name": effect_name,
			"params": params,
		})

	for effect_data in _effects:
		var effect: Dictionary = effect_data
		_apply_effect_enabled(str(effect["name"]))


func _should_ignore_param(shader_param: String) -> bool:
	return shader_param == SCREEN_TEXTURE_PARAM


func _get_enabled_property_name(effect_name: String) -> String:
	return effect_name + "_enabled"


func _get_param_property_name(effect_name: String, shader_param: String) -> String:
	return effect_name + "_" + shader_param


func _get_param_key(effect_name: String, shader_param: String) -> String:
	return effect_name + "/" + shader_param


func _get_effect_material_by_name(effect_name: String) -> ShaderMaterial:
	var node: Node = _get_effect_node_by_name(effect_name)
	if node == null:
		return null

	return _get_shader_material(node)


func _apply_effect_enabled(effect_name: String) -> void:
	var node: Node = _get_effect_node_by_name(effect_name)
	if node == null:
		return

	_set_effect_node_visible(node, bool(_enabled_states.get(effect_name, false)))


func _apply_effect_param(effect_name: String, shader_param: String, default_value: Variant) -> void:
	var material: ShaderMaterial = _get_effect_material_by_name(effect_name)
	if material == null:
		return

	var param_key: String = _get_param_key(effect_name, shader_param)
	var value: Variant = _param_values.get(param_key, default_value)
	material.set_shader_parameter(shader_param, value)


func _apply_effect(effect_data: Dictionary, warn_if_missing: bool = false) -> void:
	var effect_name: String = str(effect_data["name"])
	var node: Node = _get_effect_node_by_name(effect_name)
	if node == null:
		if warn_if_missing:
			CLog.w("PostProcess: 找不到效果节点 '%s'" % effect_name)
			return

	_set_effect_node_visible(node, bool(_enabled_states.get(effect_name, false)))

	var material: ShaderMaterial = _get_shader_material(node)
	if material == null:
		return

	for param_data in effect_data["params"]:
		var param: Dictionary = param_data
		var shader_param: String = str(param["shader_param"])
		var param_key: String = _get_param_key(effect_name, shader_param)
		var value: Variant = _param_values.get(param_key, param["default"])
		material.set_shader_parameter(shader_param, value)


func _get_property_binding(property: StringName) -> Dictionary:
	var property_name: String = str(property)
	return _property_bindings.get(property_name, {})
