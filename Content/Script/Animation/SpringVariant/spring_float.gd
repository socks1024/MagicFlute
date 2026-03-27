class_name SpringFloat
extends RefCounted
## 阻尼弹簧振荡器（float 版本）
##
## 模拟一个带阻尼的弹簧系统，支持 Bump（冲量）、MoveTo（弹性移到目标）等操作。
## 参考 Unity Feel 插件的 MMSpring 系统设计。

# ── 弹簧参数 ─────────────────────────────────────────
## 阻尼系数（0~1 之间，越大越快停下）
var damping: float = 0.6
## 频率（越大弹得越快）
var frequency: float = 6.0

# ── 运行时状态 ─────────────────────────────────────────
## 当前值
var current: float = 0.0
## 目标值（弹簧的静止点）
var target: float = 0.0
## 当前速度
var velocity: float = 0.0
## 初始值（用于 restore）
var initial: float = 0.0
## 弹簧是否低于阈值可视为静止
var is_resting: bool = true

# ── 内部常量 ─────────────────────────────────────────
## 速度和偏移量低于此阈值时视为静止
const REST_THRESHOLD: float = 0.001

# ── 构造 ─────────────────────────────────────────────

func _init(initial_value: float = 0.0, p_damping: float = 0.6, p_frequency: float = 6.0) -> void:
	current = initial_value
	target = initial_value
	initial = initial_value
	damping = p_damping
	frequency = p_frequency
	velocity = 0.0
	is_resting = true

# ── 核心更新（每帧调用） ─────────────────────────────

## 每帧更新弹簧状态，传入 delta 时间（秒）
func update(delta: float) -> void:
	if is_resting:
		return
	# 钳制 delta 防止极端帧率导致弹簧爆炸
	var clamped_delta: float = minf(delta, 0.05)
	# 阻尼弹簧振荡器公式
	# F = -k * (x - target) - d * v
	# 其中 k = (2π * frequency)^2, d = 2 * damping * (2π * frequency)
	var omega: float = TAU * frequency
	var omega_sq: float = omega * omega
	var damping_coeff: float = 2.0 * damping * omega

	# 计算加速度
	var displacement: float = current - target
	var acceleration: float = -omega_sq * displacement - damping_coeff * velocity

	# 半隐式欧拉积分（比显式欧拉更稳定）
	velocity += acceleration * clamped_delta
	current += velocity * clamped_delta

	# 检查是否可以停止
	if absf(velocity) < REST_THRESHOLD and absf(current - target) < REST_THRESHOLD:
		current = target
		velocity = 0.0
		is_resting = true

# ── 公共 API ─────────────────────────────────────────

## 给弹簧一个瞬间冲量（最核心的操作）
## amount: 期望的振荡幅度（内部自动按 omega 缩放为速度）
## 例如 bump(0.3) 大约会让弹簧偏离平衡点 0.3 个单位
func bump(amount: float) -> void:
	var omega: float = TAU * frequency
	velocity += amount * omega
	is_resting = false


## 让弹簧弹性移到目标值
func move_to(new_target: float) -> void:
	target = new_target
	is_resting = false


## 在当前目标基础上叠加偏移
func move_to_additive(delta_target: float) -> void:
	target += delta_target
	is_resting = false


## 弹性回归初始值
func restore_initial() -> void:
	target = initial
	is_resting = false


## 立即停止在当前位置
func stop() -> void:
	velocity = 0.0
	target = current
	is_resting = true


## 立即跳到目标值（无弹簧效果）
func finish() -> void:
	current = target
	velocity = 0.0
	is_resting = true


## 重置为初始状态
func reset() -> void:
	current = initial
	target = initial
	velocity = 0.0
	is_resting = true
