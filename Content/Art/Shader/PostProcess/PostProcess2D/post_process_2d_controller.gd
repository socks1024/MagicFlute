@tool
class_name PostProcess2DController
extends PostProcessControllerBase

## 2D 后处理控制器。
## 扫描所有 ColorRect 子节点上的 ShaderMaterial，
## 生成检查器面板，并统一管理效果开关与 shader 参数回写。


func _get_effect_children() -> Array[Node]:
	var result: Array[Node] = []

	for child in get_children():
		if child is ColorRect:
			result.append(child)

	return result


func _get_shader_material(node: Node) -> ShaderMaterial:
	var rect: ColorRect = node as ColorRect
	if rect == null:
		return null

	return rect.material as ShaderMaterial


func _get_effect_node_by_name(effect_name: String) -> Node:
	return get_node_or_null(NodePath(effect_name))


func _set_effect_node_visible(node: Node, visible: bool) -> void:
	var control: Control = node as Control
	if control != null:
		control.visible = visible
