# Generated class_name InputManager
extends Node
## 输入管理器 AutoLoad 单例，负责管理所有输入上下文的激活状态

## 有上下文被加入集合时发出
signal context_added(added: InputContext)
## 有上下文被移除集合时发出
signal context_removed(removed: InputContext)

## 以 context_name 为键的上下文集合，保证同名上下文不会重复添加
var _context_set: Dictionary = {}
## 所有被管理的 Action，在初始化时从 InputMap 中收集
var _all_managed_actions: Array[StringName] = []

func _ready() -> void:
	# 收集所有 Action
	for action in InputMap.get_actions():
		_all_managed_actions.append(action)

	# 添加默认的 UI 上下文
	var ui_context:InputContext = preload("uid://d2kp3854dt0kv")
	add_context(ui_context)


func _input(event: InputEvent) -> void:
	# 上下文集合为空时，拦截所有被管理的 Action
	if _context_set.is_empty():
		for action in _all_managed_actions:
			if event.is_action(action):
				get_viewport().set_input_as_handled()
				return

	# 收集集合中所有上下文的 Actions 合集
	var active_actions: Array[StringName] = []
	for context in _context_set.values():
		for action in context.actions:
			if action not in active_actions:
				active_actions.append(action)

	# 遍历所有被管理的 Action，若不在激活合集中则拦截
	for action in _all_managed_actions:
		if action not in active_actions:
			if event.is_action(action):
				get_viewport().set_input_as_handled()
				return


## 将一个上下文加入集合，其 Actions 立即生效
func add_context(context: InputContext) -> void:
	if context == null or context.context_name == &"":
		CLog.w("InputManager: 尝试添加无效的 InputContext（为空或 context_name 未设置）")
		return
	_context_set[context.context_name] = context
	context_added.emit(context)


## 按名称从集合中移除上下文，该上下文的 Actions 不再生效
func remove_context(context_name: StringName) -> void:
	if not _context_set.has(context_name):
		return
	var removed: InputContext = _context_set[context_name]
	_context_set.erase(context_name)
	context_removed.emit(removed)


## 清空上下文集合，禁用所有被管理的 InputAction
func clear_context() -> void:
	for context in _context_set.values():
		context_removed.emit(context)
	_context_set.clear()


## 获取当前所有激活上下文中的 Actions 合集
func get_active_actions() -> Array[StringName]:
	var result: Array[StringName] = []
	for context in _context_set.values():
		for action in context.actions:
			if action not in result:
				result.append(action)
	return result


## 检查某个上下文是否在集合中
func is_context_active(context_name: StringName) -> bool:
	return _context_set.has(context_name)
