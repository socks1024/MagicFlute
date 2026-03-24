class_name SpringVector3
extends RefCounted
## 阻尼弹簧振荡器（Vector3 版本）
##
## 内部使用三个 SpringFloat 分别驱动 X、Y 和 Z 轴。
## 参考 Unity Feel 插件的 MMSpring 系统设计。

# ── X/Y/Z 轴弹簧实例 ─────────────────────────────────
## X 轴弹簧
var spring_x: SpringFloat
## Y 轴弹簧
var spring_y: SpringFloat
## Z 轴弹簧
var spring_z: SpringFloat

# ── 便捷属性 ─────────────────────────────────────────

## 当前值
var current: Vector3:
	get:
		return Vector3(spring_x.current, spring_y.current, spring_z.current)
	set(value):
		spring_x.current = value.x
		spring_y.current = value.y
		spring_z.current = value.z

## 目标值
var target: Vector3:
	get:
		return Vector3(spring_x.target, spring_y.target, spring_z.target)
	set(value):
		spring_x.target = value.x
		spring_y.target = value.y
		spring_z.target = value.z

## 当前速度
var velocity: Vector3:
	get:
		return Vector3(spring_x.velocity, spring_y.velocity, spring_z.velocity)
	set(value):
		spring_x.velocity = value.x
		spring_y.velocity = value.y
		spring_z.velocity = value.z

## 弹簧是否静止
var is_resting: bool:
	get:
		return spring_x.is_resting and spring_y.is_resting and spring_z.is_resting

# ── 构造 ─────────────────────────────────────────────

func _init(initial_value: Vector3 = Vector3.ZERO, p_damping: float = 0.6, p_frequency: float = 6.0) -> void:
	spring_x = SpringFloat.new(initial_value.x, p_damping, p_frequency)
	spring_y = SpringFloat.new(initial_value.y, p_damping, p_frequency)
	spring_z = SpringFloat.new(initial_value.z, p_damping, p_frequency)

# ── 参数设置 ─────────────────────────────────────────

## 同时设置三轴的阻尼
func set_damping(value: float) -> void:
	spring_x.damping = value
	spring_y.damping = value
	spring_z.damping = value

## 同时设置三轴的频率
func set_frequency(value: float) -> void:
	spring_x.frequency = value
	spring_y.frequency = value
	spring_z.frequency = value

# ── 核心更新（每帧调用） ─────────────────────────────

## 每帧更新弹簧状态
func update(delta: float) -> void:
	spring_x.update(delta)
	spring_y.update(delta)
	spring_z.update(delta)

# ── 公共 API ─────────────────────────────────────────

## 给弹簧一个瞬间冲量
func bump(amount: Vector3) -> void:
	spring_x.bump(amount.x)
	spring_y.bump(amount.y)
	spring_z.bump(amount.z)

## 让弹簧弹性移到目标值
func move_to(new_target: Vector3) -> void:
	spring_x.move_to(new_target.x)
	spring_y.move_to(new_target.y)
	spring_z.move_to(new_target.z)

## 在当前目标基础上叠加偏移
func move_to_additive(delta_target: Vector3) -> void:
	spring_x.move_to_additive(delta_target.x)
	spring_y.move_to_additive(delta_target.y)
	spring_z.move_to_additive(delta_target.z)

## 弹性回归初始值
func restore_initial() -> void:
	spring_x.restore_initial()
	spring_y.restore_initial()
	spring_z.restore_initial()

## 立即停止在当前位置
func stop() -> void:
	spring_x.stop()
	spring_y.stop()
	spring_z.stop()

## 立即跳到目标值
func finish() -> void:
	spring_x.finish()
	spring_y.finish()
	spring_z.finish()

## 重置为初始状态
func reset() -> void:
	spring_x.reset()
	spring_y.reset()
	spring_z.reset()
