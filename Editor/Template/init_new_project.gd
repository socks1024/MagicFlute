@tool
extends EditorScript

# ============================================================
#  新项目初始化脚本
#  使用方法：在 Godot 编辑器中打开此脚本，点击右上角"运行"按钮
#  功能：
#    1. 删除不需要的目录（.git 等）
# ============================================================

# 需要删除的目录列表（相对于项目根目录）
const DIRS_TO_REMOVE: Array[String] = [
	".git",
]


func _run() -> void:
	var project_root: String = ProjectSettings.globalize_path("res://")
	# 去掉末尾斜杠，方便后续处理
	project_root = project_root.rstrip("/").rstrip("\\")

	print("=== 新项目初始化 ===")
	print("项目根目录：", project_root)
	print("")

	# ---------- 删除排除目录 ----------
	for dir_name in DIRS_TO_REMOVE:
		var dir_path: String = project_root.path_join(dir_name)
		if DirAccess.dir_exists_absolute(dir_path):
			print("正在删除目录：", dir_name, " ...")
			var err: Error = _remove_dir_recursive(dir_path)
			if err == OK:
				print("  ✓ 已删除：", dir_name)
			else:
				push_error("  ✗ 删除失败：" + dir_name + "（错误码：" + str(err) + "）")
		else:
			print("  跳过（不存在）：", dir_name)

	print("")
	print("=== 初始化完成！===")


# 递归删除目录
func _remove_dir_recursive(path: String) -> Error:
	var dir := DirAccess.open(path)
	if dir == null:
		return DirAccess.get_open_error()

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path: String = path.path_join(file_name)
			if dir.current_is_dir():
				var err: Error = _remove_dir_recursive(full_path)
				if err != OK:
					return err
			else:
				var err: Error = dir.remove(file_name)
				if err != OK:
					return err
		file_name = dir.get_next()
	dir.list_dir_end()

	# 删除空目录本身
	return DirAccess.remove_absolute(path)
