class_name SceneUtils

## 快速实例化 PackedScene，可以传入 Callable 对节点进行初始化
static func quick_instantiate(parent:Node, p_scene:PackedScene, init_callable = null) -> Node:
	var n = p_scene.instantiate()
	if init_callable && init_callable is Callable:
		init_callable.call(n)
	parent.add_child(n)
	return n

## 在 parent 节点下创建根据 scene_path 指定的场景
static func quick_instantiate_by_path(parent:Node, scene_path:String, init_callable = null) -> Node:
	var packed_new_scene:PackedScene = ResourceLoader.load(scene_path)
	return quick_instantiate(parent, packed_new_scene, init_callable)

## 在 parent 节点下，通过 load_scene_path 指定的场景创建过渡，并加载 scene_path 指定的场景
static func instantiate_scene_by_load_control(parent:Node, scene_path:String, load_scene_path:String, min_load_time:float = -1, confirm_time = -1) -> Node:
	var load_scene:LoadControl = quick_instantiate_by_path(parent, load_scene_path, func(ls):
		ls.path = scene_path
		if min_load_time > 0: ls.min_load_time = min_load_time
		if confirm_time > 0: ls.confirm_time = confirm_time)
	
	var res = await load_scene.load_finish
	return quick_instantiate(parent, res)

## 将 from 替换为 to 指定的场景，新场景将被添加到 from 的父节点下
static func switch_scene_by_path(from_scene:Node, to_scene_path:String) -> Node:
	from_scene.queue_free()
	
	var parent_node:Node = from_scene.get_parent()
	
	return quick_instantiate_by_path(parent_node, to_scene_path)

## 通过加载界面加载场景，将 from 替换为 to 指定的场景，在 to 加载时，会以 load_scene 作为过渡
static func switch_scene_by_load_control(from_scene:Node, to_scene_path:String, load_scene_path:String, min_load_time:float = -1, confirm_time = -1) -> Node:
	from_scene.queue_free()
	
	var parent_node:Node = from_scene.get_parent()
	
	return await instantiate_scene_by_load_control(parent_node, to_scene_path, load_scene_path, min_load_time, confirm_time)
