class_name SpringVector2
extends RefCounted
## 阻尼弹簧振荡器（Vector2 版本）
##
## 内部使用两个 SpringFloat 分别驱动 X 和 Y 轴。
## 参考 Unity Feel 插件的 MMSpring 系统设计。

# ── X/Y 轴弹簧实例 ───────────────────────────────────
## X 轴弹簧
var spring_x: SpringFloat
## Y 轴弹簧
var spring_y: SpringFloat

# ── 便捷属性 ─────────────────────────────────────────

## 当前值
var current: Vector2:
	get:
		return Vector2(spring_x.current, spring_y.current)
	set(value):
		spring_x.current = value.x
		spring_y.current = value.y

## 目标值
var target: Vector2:
	get:
		return Vector2(spring_x.target, spring_y.target)
	set(value):
		spring_x.target = value.x
		spring_y.target = value.y

## 当前速度
var velocity: Vector2:
	get:
		return Vector2(spring_x.velocity, spring_y.velocity)
	set(value):
		spring_x.velocity = value.x
		spring_y.velocity = value.y

## 弹簧是否静止
var is_resting: bool:
	get:
		return spring_x.is_resting and spring_y.is_resting

# ── 构造 ─────────────────────────────────────────────

func _init(initial_value: Vector2 = Vector2.ZERO, p_damping: float = 0.6, p_frequency: float = 6.0) -> void:
	spring_x = SpringFloat.new(initial_value.x, p_damping, p_frequency)
	spring_y = SpringFloat.new(initial_value.y, p_damping, p_frequency)

# ── 参数设置 ─────────────────────────────────────────

## 同时设置两轴的阻尼
func set_damping(value: float) -> void:
	spring_x.damping = value
	spring_y.damping = value


## 同时设置两轴的频率
func set_frequency(value: float) -> void:
	spring_x.frequency = value
	spring_y.frequency = value

# ── 核心更新（每帧调用） ─────────────────────────────

## 每帧更新弹簧状态
func update(delta: float) -> void:
	spring_x.update(delta)
	spring_y.update(delta)

# ── 公共 API ─────────────────────────────────────────

## 给弹簧一个瞬间冲量
func bump(amount: Vector2) -> void:
	spring_x.bump(amount.x)
	spring_y.bump(amount.y)


## 让弹簧弹性移到目标值
func move_to(new_target: Vector2) -> void:
	spring_x.move_to(new_target.x)
	spring_y.move_to(new_target.y)


## 在当前目标基础上叠加偏移
func move_to_additive(delta_target: Vector2) -> void:
	spring_x.move_to_additive(delta_target.x)
	spring_y.move_to_additive(delta_target.y)


## 弹性回归初始值
func restore_initial() -> void:
	spring_x.restore_initial()
	spring_y.restore_initial()


## 立即停止在当前位置
func stop() -> void:
	spring_x.stop()
	spring_y.stop()


## 立即跳到目标值
func finish() -> void:
	spring_x.finish()
	spring_y.finish()


## 重置为初始状态
func reset() -> void:
	spring_x.reset()
	spring_y.reset()
