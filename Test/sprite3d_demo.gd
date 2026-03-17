extends Node3D
## Sprite3D 演示场景脚本
## 展示 Sprite3D 的多种使用方式

@onready var normal_sprite: Sprite3D = $NormalSprite
@onready var billboard_sprite: Sprite3D = $BillboardSprite
@onready var spinning_sprite: Sprite3D = $SpinningSprite
@onready var color_sprite: Sprite3D = $ColorSprite
@onready var camera: Camera3D = $Camera3D
@onready var label: Label = $CanvasLayer/Label

@onready var world_ui_viewport: SubViewport = $NormalSprite/WorldSpaceUI
@onready var world_ui_sprite: Sprite3D = $NormalSprite/WorldSpaceUISprite
@onready var hp_bar: ProgressBar = $NormalSprite/WorldSpaceUI/Panel/VBox/HPBar

var time: float = 0.0
var camera_angle: float = 0.0

func _ready() -> void:

	print("=== Sprite3D 演示场景 ===")
	print("按 1 键：切换普通 Sprite 的 shaded（是否受光照影响）")
	print("按 2 键：切换 Billboard Sprite 的广告牌模式")
	print("按 3 键：切换旋转方向")
	print("按 4 键：切换世界空间 UI 显示")
	print("按 鼠标左键/右键：旋转相机视角")
	print("========================")

var spin_direction: float = 1.0

func _process(delta: float) -> void:
	time += delta

	# --- 旋转的 Sprite ---
	spinning_sprite.rotation.y += delta * 2.0 * spin_direction

	# --- 颜色变化的 Sprite ---
	var r := (sin(time * 1.5) + 1.0) / 2.0
	var g := (sin(time * 1.5 + TAU / 3.0) + 1.0) / 2.0
	var b := (sin(time * 1.5 + TAU * 2.0 / 3.0) + 1.0) / 2.0
	color_sprite.modulate = Color(r, g, b, 1.0)

	# --- 世界空间 UI 血条动画 ---
	var hp_value := (sin(time * 0.8) + 1.0) / 2.0 * 100.0
	hp_bar.value = hp_value
	# 根据血量改变血条颜色
	var fill_style: StyleBoxFlat = hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		if hp_value > 50.0:
			fill_style.bg_color = Color(0.2, 0.85, 0.3, 1)  # 绿色
		elif hp_value > 25.0:
			fill_style.bg_color = Color(0.9, 0.8, 0.1, 1)  # 黄色
		else:
			fill_style.bg_color = Color(0.9, 0.15, 0.15, 1)  # 红色

	# --- 相机绕场景旋转 ---
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		camera_angle += delta * 0.8
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_angle -= delta * 0.8

	var cam_radius := 6.0
	var cam_height := 3.0
	camera.position = Vector3(
		cos(camera_angle) * cam_radius,
		cam_height,
		sin(camera_angle) * cam_radius
	)
	camera.look_at(Vector3(0, 0.5, 0))

	# --- 更新说明文字 ---
	_update_label()

func _update_label() -> void:
	var shaded_text := "开启" if normal_sprite.shaded else "关闭"
	var billboard_text: String
	match billboard_sprite.billboard:
		BaseMaterial3D.BILLBOARD_DISABLED:
			billboard_text = "关闭"
		BaseMaterial3D.BILLBOARD_ENABLED:
			billboard_text = "始终面向相机"
		BaseMaterial3D.BILLBOARD_FIXED_Y:
			billboard_text = "仅Y轴面向相机"
	var spin_text := "正向" if spin_direction > 0 else "反向"

	label.text = """[Sprite3D 演示]
按 1：切换光照 (当前: %s)
按 2：切换广告牌模式 (当前: %s)
按 3：切换旋转方向 (当前: %s)
按 4：切换世界空间 UI (当前: %s)
鼠标左键/右键：旋转相机

左: 普通Sprite+世界UI | 中左: 旋转中 | 中右: 颜色变化 | 右: 广告牌模式""" % [shaded_text, billboard_text, spin_text, "显示" if world_ui_sprite.visible else "隐藏"]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				# 切换光照
				normal_sprite.shaded = !normal_sprite.shaded
				print("普通 Sprite 光照: ", "开启" if normal_sprite.shaded else "关闭")
			KEY_2:
				# 循环切换广告牌模式
				match billboard_sprite.billboard:
					BaseMaterial3D.BILLBOARD_DISABLED:
						billboard_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
						print("广告牌模式: 始终面向相机")
					BaseMaterial3D.BILLBOARD_ENABLED:
						billboard_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
						print("广告牌模式: 仅Y轴面向相机")
					BaseMaterial3D.BILLBOARD_FIXED_Y:
						billboard_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
						print("广告牌模式: 关闭")
			KEY_3:
				# 切换旋转方向
				spin_direction *= -1.0
				print("旋转方向: ", "正向" if spin_direction > 0 else "反向")
			KEY_4:
				# 切换世界空间 UI 显示
				world_ui_sprite.visible = !world_ui_sprite.visible
				world_ui_viewport.render_target_update_mode = (
					SubViewport.UPDATE_ALWAYS if world_ui_sprite.visible
					else SubViewport.UPDATE_DISABLED
				)
				print("世界空间 UI: ", "显示" if world_ui_sprite.visible else "隐藏")
