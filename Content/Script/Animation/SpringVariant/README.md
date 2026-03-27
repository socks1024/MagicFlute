# Spring 弹簧系统使用文档

基于阻尼弹簧振荡器的弹性运动系统，适用于位置、缩放、旋转等任何需要"弹弹的"手感的场景。

---

## 快速上手

### 1. 声明弹簧变量

```gdscript
# float 版本（用于旋转、透明度、单轴数值等）
var _rotation_spring: SpringFloat

# Vector2 版本（用于位置、缩放等）
var _scale_spring: SpringVector2
```

### 2. 初始化

在 `_ready()` 中创建实例：

```gdscript
func _ready() -> void:
	# SpringFloat(初始值, 阻尼, 频率)
	_rotation_spring = SpringFloat.new(0.0, 0.6, 6.0)

	# SpringVector2(初始值, 阻尼, 频率)
	_scale_spring = SpringVector2.new(Vector2.ONE, 0.5, 8.0)
```

### 3. 每帧更新

在 `_physics_process()` 中调用 `update()`，然后把 `current` 应用到节点属性上：

```gdscript
func _process(delta: float) -> void:
	_rotation_spring.update(delta)
	_scale_spring.update(delta)

	# 应用到节点
	rotation = _rotation_spring.current
	scale = _scale_spring.current
```

### 4. 触发效果

在需要的时候调用 API：

```gdscript
# 受击时缩放弹一下
_scale_spring.bump(Vector2(-0.3, 0.4))

# 跳跃时旋转弹一下
_rotation_spring.bump(0.5)
```

---

## 构造参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `initial_value` | `float` / `Vector2` | `0.0` / `Vector2.ZERO` | 弹簧的初始值（也是 `restore_initial` 回归的目标） |
| `p_damping` | `float` | `0.6` | 阻尼系数，范围 `0~1`。越大越快停下；`0` = 永远振荡，`1` = 临界阻尼（无振荡直接到位） |
| `p_frequency` | `float` | `6.0` | 频率，越大弹得越快、越紧 |

### 参数调节建议

| 效果 | damping | frequency | 说明 |
|------|---------|-----------|------|
| 弹性十足 | 0.3~0.5 | 4~6 | 明显的来回振荡 |
| 快速响应 | 0.6~0.8 | 8~12 | 快速弹到位，轻微过冲 |
| 果冻感 | 0.2~0.4 | 2~4 | 慢悠悠地晃 |
| 干脆利落 | 0.9~1.0 | 10+ | 几乎无振荡，快速到位 |

---

## API 参考

以下 API 在 `SpringFloat` 和 `SpringVector2` 中完全一致，只是参数类型不同（`float` vs `Vector2`）。

### `update(delta: float) -> void`

每帧调用，驱动弹簧物理。**必须调用，否则弹簧不会动。**
必须在 `_physics_process()` 中调用，保证稳定的帧率，否则可能会出现意料之外的情况。

```gdscript
func _physics_process(delta: float) -> void:
	my_spring.update(delta)
```

---

### `bump(amount) -> void`

**最核心的操作。** 给弹簧一个瞬间冲量，让它从当前位置弹开。

- `amount` 的含义是**期望的振荡幅度**（不是原始速度），例如 `bump(0.3)` 大约会让弹簧偏离平衡点 0.3 个单位
- 多次调用会叠加

```gdscript
# 受击 → 缩放回弹
_scale_spring.bump(Vector2(-0.3, 0.4))

# 跳跃 → 位置向上弹
_position_spring.bump(Vector2(0.0, -50.0))

# 旋转抖动
_rotation_spring.bump(0.5)
```

---

### `move_to(new_target) -> void`

让弹簧**弹性地**移到新的目标值。弹簧会从当前位置以弹性方式过渡到目标。

```gdscript
# 角色缩放弹性变为 2 倍
_scale_spring.move_to(Vector2(2.0, 2.0))
```

---

### `move_to_additive(delta_target) -> void`

在当前目标值基础上**叠加**偏移。适合连续施加的效果。

```gdscript
# 每次点击让位置目标右移 10
_position_spring.move_to_additive(Vector2(10.0, 0.0))
```

---

### `restore_initial() -> void`

弹性回归到构造时的初始值。适合"效果结束后恢复原状"。

```gdscript
# 回到初始缩放
_scale_spring.restore_initial()
```

---

### `stop() -> void`

立即停止，弹簧冻结在当前位置（target 也设为当前位置）。

---

### `finish() -> void`

立即跳到目标值，无弹性过渡。适合需要瞬间完成的场景。

---

### `reset() -> void`

完全重置为初始状态（current、target、velocity 全部归零到初始值）。

---

### 只读属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `current` | `float` / `Vector2` | 当前值，每帧读取并应用到节点属性 |
| `target` | `float` / `Vector2` | 当前目标值 |
| `velocity` | `float` / `Vector2` | 当前速度 |
| `is_resting` | `bool` | 弹簧是否已静止 |

---

### SpringVector2 / SpringVector3 专有方法

| 方法 | 说明 |
|------|------|
| `set_damping(value: float)` | 同时设置所有轴的阻尼 |
| `set_frequency(value: float)` | 同时设置所有轴的频率 |

也可以单独调节某一轴：

```gdscript
_scale_spring.spring_x.damping = 0.3  # 只改 X 轴阻尼
_scale_spring.spring_y.frequency = 10.0  # 只改 Y 轴频率
_position_spring.spring_z.damping = 0.8  # 只改 Z 轴阻尼（仅 SpringVector3）
```

---

## 完整示例：角色受击反馈

```gdscript
extends CharacterBody2D

var _scale_spring: SpringVector2
var _position_spring: SpringVector2
var _base_position: Vector2

func _ready() -> void:
	_scale_spring = SpringVector2.new(Vector2.ONE, 0.5, 8.0)
	_position_spring = SpringVector2.new(Vector2.ZERO, 0.6, 6.0)
	_base_position = position

func _physics_process(delta: float) -> void:
	_scale_spring.update(delta)
	_position_spring.update(delta)

	scale = _scale_spring.current
	position = _base_position + _position_spring.current

## 被攻击时调用
func take_damage(from_direction: Vector2) -> void:
	# 缩放挤压
	_scale_spring.bump(Vector2(-0.3, 0.3))
	# 击退抖动
	_position_spring.bump(from_direction.normalized() * 20.0)
```

## 完整示例：UI 按钮弹性

```gdscript
extends Button

var _scale_spring: SpringVector2

func _ready() -> void:
	_scale_spring = SpringVector2.new(Vector2.ONE, 0.4, 10.0)
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)
	pressed.connect(_on_pressed)

func _physics_process(delta: float) -> void:
	_scale_spring.update(delta)
	scale = _scale_spring.current

func _on_hover() -> void:
	_scale_spring.move_to(Vector2(1.1, 1.1))

func _on_unhover() -> void:
	_scale_spring.restore_initial()

func _on_pressed() -> void:
	_scale_spring.bump(Vector2(-0.2, -0.2))
```

---

## 完整示例：3D 角色受击反馈

```gdscript
extends CharacterBody3D

var _scale_spring: SpringVector3
var _position_spring: SpringVector3
var _base_position: Vector3

func _ready() -> void:
	_scale_spring = SpringVector3.new(Vector3.ONE, 0.5, 8.0)
	_position_spring = SpringVector3.new(Vector3.ZERO, 0.6, 6.0)
	_base_position = position

func _physics_process(delta: float) -> void:
	_scale_spring.update(delta)
	_position_spring.update(delta)

	scale = _scale_spring.current
	position = _base_position + _position_spring.current

## 被攻击时调用
func take_damage(from_direction: Vector3) -> void:
	# 缩放挤压
	_scale_spring.bump(Vector3(-0.2, 0.3, -0.2))
	# 击退抖动
	_position_spring.bump(from_direction.normalized() * 15.0)
```

---

## bump vs move_to 怎么选？

| 场景 | 推荐 API | 原因 |
|------|----------|------|
| 受击、跳跃、点击等**瞬间事件** | `bump()` | 给一个冲量让弹簧自己弹回来 |
| 悬停放大、切换状态等**持续目标** | `move_to()` | 弹性过渡到新目标并停留 |
| 效果结束后恢复 | `restore_initial()` | 弹回初始值 |
| 连续叠加的效果 | `move_to_additive()` | 在当前目标上不断累加 |
