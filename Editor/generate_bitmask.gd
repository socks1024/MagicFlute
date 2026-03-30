@tool
extends EditorScript

# ============================================================
#  根据图片透明度通道生成 BitMap 工具脚本
#  使用方法：在 Godot 编辑器中打开此脚本，点击右上角"运行"按钮
#  功能：
#    扫描 SOURCE_DIR 目录下的所有图片文件，
#    根据透明度通道生成对应的 BitMap (.tres)，
#    保存在图片同目录下，文件名为 "原文件名_bitmask.tres"
#  注意：
#    已存在同名 .tres 文件时会跳过，不会覆盖
# ============================================================

## 要扫描的目录（修改为你需要的路径）
const SOURCE_DIR: String = "res://Content/Art/Sprite/结算"
## 透明度阈值（0.0 ~ 1.0），低于此值的像素视为透明
const ALPHA_THRESHOLD: float = 0.1
## 支持的图片扩展名
const IMAGE_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp", "bmp", "svg"]


func _run() -> void:
	print("=== 开始生成 BitMask ===")
	print("扫描目录：", SOURCE_DIR)
	print("透明度阈值：", ALPHA_THRESHOLD)
	print("")

	var count: int = 0
	var skip_count: int = 0
	var fail_count: int = 0
	var files: Array[String] = _collect_image_files(SOURCE_DIR)

	print("找到 ", files.size(), " 张图片")
	print("")

	for file_path in files:
		var output_path: String = _get_output_path(file_path)

		# 已存在则跳过
		if ResourceLoader.exists(output_path):
			skip_count += 1
			continue

		var bitmap: BitMap = _generate_bitmask(file_path)
		if bitmap == null:
			fail_count += 1
			continue

		var err: Error = ResourceSaver.save(bitmap, output_path)
		if err == OK:
			count += 1
			print("  ✓ 已生成：", output_path)
		else:
			fail_count += 1
			push_error("  ✗ 保存失败：" + output_path + "（错误码：" + str(err) + "）")

	print("")
	print("=== 生成完成 ===")
	print("  新生成：", count)
	print("  已跳过：", skip_count)
	print("  失败：", fail_count)


## 根据图片透明度通道生成 BitMap
func _generate_bitmask(image_path: String) -> BitMap:
	var texture: Texture2D = load(image_path) as Texture2D
	if texture == null:
		push_error("无法加载纹理：" + image_path)
		return null

	var image: Image = texture.get_image()
	if image == null:
		push_error("无法获取图片数据：" + image_path)
		return null

	var bitmap: BitMap = BitMap.new()
	bitmap.create_from_image_alpha(image, ALPHA_THRESHOLD)
	return bitmap


## 根据图片路径生成输出路径（同目录，文件名加 _bitmask 后缀）
func _get_output_path(image_path: String) -> String:
	var base: String = image_path.get_basename()
	return base + "_bitmask.tres"


## 递归收集目录下所有图片文件
func _collect_image_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_error("无法打开目录：" + dir_path)
		return result

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var full_path: String = dir_path.path_join(file_name)
		if dir.current_is_dir():
			# 跳过隐藏目录
			if not file_name.begins_with("."):
				result.append_array(_collect_image_files(full_path))
		else:
			var ext: String = file_name.get_extension().to_lower()
			if ext in IMAGE_EXTENSIONS:
				result.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

	return result
