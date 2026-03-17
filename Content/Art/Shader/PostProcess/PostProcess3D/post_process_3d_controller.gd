@tool
class_name PostProcess3DController
extends PostProcessControllerBase

## 3D 后处理控制器。
## 作为 Camera3D 的子节点使用，扫描所有 MeshInstance3D 子节点上的 ShaderMaterial，
## 生成检查器面板，并统一管理效果开关与 shader 参数回写。
##
## 场景结构示例：
##   Camera3D
##     └─ PostProcess3DController (本脚本)
##         ├─ Outline (MeshInstance3D, QuadMesh 2×2 flip_faces, ShaderMaterial)
##         └─ ...

## 需要忽略的内置深度/法线纹理参数
const DEPTH_TEXTURE_PARAM: String = "DEPTH_TEXTURE"
const NORMR_TEXTURE_PARAM: String = "NORMR_TEXTURE"


func _get_effect_children() -> Array[Node]:
	var result: Array[Node] = []

	for child in get_children():
		if child is MeshInstance3D:
			result.append(child)

	return result


func _get_shader_material(node: Node) -> ShaderMaterial:
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance == null:
		return null

	return mesh_instance.material_override as ShaderMaterial


func _get_effect_node_by_name(effect_name: String) -> Node:
	return get_node_or_null(NodePath(effect_name))


func _set_effect_node_visible(node: Node, visible: bool) -> void:
	var node_3d: Node3D = node as Node3D
	if node_3d != null:
		node_3d.visible = visible


func _should_ignore_param(shader_param: String) -> bool:
	return (
		shader_param == SCREEN_TEXTURE_PARAM
		or shader_param == DEPTH_TEXTURE_PARAM
		or shader_param == NORMR_TEXTURE_PARAM
	)
