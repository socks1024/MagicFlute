## 魔笛（暂定名）- 程序实现文档（P0/P1骨架）

### 1. 文档范围
- **目标**：给出可直接落地的脚本类清单，以及每个类的变量与函数签名。
- **约束**：只写声明，不写具体实现逻辑。
- **当前版本重点**：
  - 同一首曲子、同一 BPM、同一拍点时间轴。
  - 判定仅 `Hit/Miss`。
  - 常态移动与音游模式共用统一节拍主时钟。

### 2. 建议脚本结构
- `res://Content/Scripts/Core/game_root.gd`：游戏主循环脚本，负责节奏相关逻辑（时间逻辑、输入判断逻辑、普通移动模式和音游模式之间的切换、决定音游模式的具体谱子等）、游戏交互（完成音游模式后清屏杀怪、生成魔笛等）。
- `res://Content/Scripts/Player/player.gd`：玩家脚本，负责常态移动、冲刺充能/释放、受伤与死亡。
- `res://Content/Scripts/Enemy/enemy_manager.gd`：敌人管理器，负责刷怪节奏、实例管理、查询与批量清除（不承载单体敌人行为）。
- `res://Content/Scripts/Enemy/enemy.gd`：单体敌人脚本，负责单个敌人的移动、受伤、死亡与基础行为。

### 3. 统一约定
- **判定枚举**：`enum HitJudge { MISS = 0, HIT = 1 }`
- **模式枚举**：`enum PlayMode { MOVE = 0, RHYTHM = 1 }`
- **时间基准**：所有节拍计算均基于同一个 `song_time_sec`（主时钟）。

### 4. 类文档清单（字段 + 方法签名）

#### 4.1 `GameRoot`
- **脚本路径**：`res://Content/Scripts/Core/game_root.gd`
- **职责**：管理统一节拍主时钟、模式切换、音游输入判定、音游结算交互（清屏/生成魔笛）。
- **备注**：当前版本不含 Boss 战，玩家持续击杀小怪推进流程。

**字段**

**导出变量（@export）**
- `@export var bpm: float`：当前关卡全局 BPM（可调节核心参数）。
- `@export var first_beat_time_sec: float`：首拍偏移时间（秒）。
- `@export var current_chart_id: StringName`：默认音游谱面 ID（可在场景中静态指定）。
- `@export var hit_window_early_sec: float`：判定窗口提前量（秒）。
- `@export var hit_window_late_sec: float`：判定窗口滞后量（秒）。
- `@export var player_ref: Player`：玩家引用（优先通过场景静态绑定）。
- `@export var enemy_manager_ref: EnemyManager`：敌人管理器引用（优先通过场景静态绑定）。
**内部变量（运行时）**
- `var seconds_per_beat: float`：每拍时长（秒），由 BPM 推导（运行时派生值）。
- `var song_time_sec: float`：歌曲当前播放时间（秒），作为节拍主时钟基准。
- `var current_beat_index: int`：当前节拍索引。
- `var mode: int`：当前模式（`PlayMode`）。
- `var is_song_playing: bool`：歌曲是否处于播放状态。
- `var pending_spawn_flute: bool`：音游结算后是否待生成魔笛。

**方法签名**
- `func initialize_run(song_id: StringName, target_bpm: float, beat_offset_sec: float) -> void`
  - 初始化一局流程，设置歌曲、BPM、首拍偏移并重置节拍状态。
- `func bind_scene_refs(player: Player, enemy_manager: EnemyManager) -> void`
  - 绑定玩家、敌人管理器引用。
- `func start_song() -> void`
  - 开始歌曲播放并激活主时钟。
- `func stop_song() -> void`
  - 停止歌曲播放并暂停节拍推进。
- `func tick_main_clock(delta: float) -> void`
  - 推进主时钟与节拍索引。
- `func compute_beat_index(at_time_sec: float) -> int`
  - 根据时间计算节拍索引。
- `func get_beat_time_sec(beat_index: int) -> float`
  - 获取指定节拍对应的绝对时间。
- `func switch_mode(next_mode: int) -> void`
  - 切换常态模式与音游模式。
- `func enter_rhythm_mode(chart_id: StringName) -> void`
  - 进入音游模式并锁定当前谱面。
- `func exit_rhythm_mode() -> void`
  - 退出音游模式并恢复常态控制。
- `func evaluate_input(action_name: StringName, input_time_sec: float) -> int`
  - 对输入进行节奏判定，仅返回 `Hit/Miss`。
- `func is_in_hit_window(input_time_sec: float, target_beat_index: int) -> bool`
  - 判断输入是否落在目标节拍判定窗口内。
- `func choose_chart_for_rhythm_phase() -> StringName`
  - 选择本轮音游阶段使用的谱面。
- `func on_rhythm_phase_completed(hit_count: int, miss_count: int) -> void`
  - 音游阶段结束后的结算入口。
- `func clear_enemies_after_rhythm() -> int`
  - 清屏敌人并返回清除数量。
- `func spawn_magic_flute(world_position: Vector2) -> Node2D`
  - 在指定位置生成魔笛对象并返回引用。

#### 4.2 `Player`
- **脚本路径**：`res://Content/Scripts/Player/player.gd`
- **职责**：处理玩家常态移动、冲刺充能/释放、受伤与死亡。

**字段**

**导出变量（@export）**
- `@export var move_speed: float`：常态移动速度。
- `@export var max_hp: int`：最大生命值。
- `@export var dash_steps_per_dash: int`：触发一次冲刺所需步数。
- `@export var dash_distance: float`：冲刺位移距离。

**内部变量（运行时）**
- `var current_hp: int`：当前生命值（运行时状态）。
- `var dash_step_charge_current: int`：当前充能值。
- `var is_dead: bool`：是否死亡（运行时状态）。
- `var is_rhythm_mode_locked: bool`：音游模式下是否锁定常态输入（运行时状态）。
- `var invincible_time_left_sec: float`：受伤无敌剩余时间（运行时状态）。

**方法签名**
- `func setup(initial_hp: int) -> void`
  - 初始化玩家状态（生命、冲刺资源、锁定状态）。
- `func set_rhythm_mode_locked(locked: bool) -> void`
  - 设置音游模式下的常态输入锁定状态。
- `func move_by_input(input_vector: Vector2, delta: float) -> void`
  - 根据输入向量执行移动；若步进充能已满，本次移动自动变为冲刺（消耗全部充能）。
- `func is_dash_charge_full() -> bool`
  - 判断步进充能是否已达到冲刺阈值。
- `func clear_dash_charge() -> void`
  - 清空步进充能（冲刺完成后调用）。
- `func add_dash_step_charge(step_count: int) -> void`
  - 按移动步数累加冲刺充能。
- `func apply_damage(amount: int, source: Node) -> void`
  - 处理受伤、扣血与死亡判定。
- `func heal(amount: int) -> void`
  - 回复生命值（不超过上限）。
- `func is_alive() -> bool`
  - 返回当前是否存活。
- `func die() -> void`
  - 执行死亡流程。
- `func respawn(position: Vector2, hp: int) -> void`
  - 按指定位置与生命值重生。

#### 4.3 `EnemyManager`
- **脚本路径**：`res://Content/Scripts/Enemy/enemy_manager.gd`
- **职责**：按节拍刷怪、维护实例集合、查询敌人、批量清除敌人。

**字段**

**导出变量（@export）**
- `@export var enemy_scene: PackedScene`：敌人预制体。
- `@export var spawn_points: Array[Node2D]`：刷怪点集合（优先场景静态配置）。
- `@export var spawn_enabled: bool`：是否启用刷怪。
- `@export var spawn_beat_interval: int`：按拍刷怪间隔。
- `@export var max_alive_count: int`：场上敌人数量上限。
- `@export var rng_seed: int`：随机种子（用于复现/调试）。

**内部变量（运行时）**
- `var active_enemies: Array[Enemy]`：存活敌人集合（运行时状态）。
- `var last_spawn_beat_index: int`：最近一次刷怪拍点（运行时状态）。

**方法签名**
- `func setup(spawn_scene: PackedScene, points: Array[Node2D]) -> void`
  - 初始化刷怪资源与刷怪点。
- `func set_spawn_enabled(enabled: bool) -> void`
  - 启用或暂停刷怪。
- `func on_beat(beat_index: int) -> int`
  - 在节拍触发时尝试刷怪，返回本次新增数量。
- `func try_spawn_enemy_at(point: Node2D) -> Enemy`
  - 在指定刷怪点尝试生成敌人并返回实例。
- `func register_enemy(enemy: Enemy) -> void`
  - 注册新生成敌人到集合。
- `func unregister_enemy(enemy: Enemy) -> void`
  - 从集合中移除敌人。
- `func get_alive_count() -> int`
  - 获取当前存活敌人数。
- `func get_alive_enemies() -> Array[Enemy]`
  - 获取当前存活敌人列表。
- `func find_nearest_enemy(world_position: Vector2, max_distance: float) -> Enemy`
  - 查询指定位置附近最近敌人。
- `func clear_all_enemies(reason: StringName) -> int`
  - 批量清除敌人并返回清除数量。
- `func despawn_out_of_bounds(bounds: Rect2) -> int`
  - 清理越界敌人并返回清理数量。

#### 4.4 `Enemy`
- **脚本路径**：`res://Content/Scripts/Enemy/enemy.gd`
- **职责**：单体敌人的移动、受伤、死亡与基础行为。

**字段**

**导出变量（@export）**
- `@export var max_hp: int`：最大生命值。
- `@export var move_speed: float`：移动速度。
- `@export var contact_damage: int`：接触伤害。
- `@export var target_player: Player`：目标玩家引用（可场景静态绑定，也可运行时覆盖）。
- `@export var reward_score: int`：击杀奖励分值。

**内部变量（运行时）**
- `var current_hp: int`：当前生命值（运行时状态）。
- `var is_dead: bool`：是否死亡（运行时状态）。
- `var knockback_velocity: Vector2`：当前击退速度（运行时状态）。
- `var stun_left_sec: float`：剩余硬直时长（运行时状态）。

**方法签名**
- `func initialize(player: Player, hp: int, speed: float) -> void`
  - 初始化单体敌人基础参数。
- `func set_target_player(player: Player) -> void`
  - 设置追踪目标玩家。
- `func tick_behavior(delta: float) -> void`
  - 推进敌人基础行为逻辑。
- `func move_toward_target(delta: float) -> void`
  - 朝目标执行移动。
- `func apply_damage(amount: int, source: Node) -> void`
  - 处理受伤、扣血与死亡判定。
- `func apply_knockback(impulse: Vector2, stun_sec: float) -> void`
  - 施加击退与硬直。
- `func can_deal_contact_damage() -> bool`
  - 判断当前是否可造成接触伤害。
- `func deal_contact_damage(player: Player) -> void`
  - 对玩家结算接触伤害。
- `func kill(reason: StringName) -> void`
  - 执行死亡流程。
- `func on_cleared_by_rhythm() -> void`
  - 响应音游结算触发的清屏击杀。

### 5. 实现约束复述（用于开发期对齐）
- 所有方法当前阶段仅做签名定义，不写实现细节。
- 判定系统仅保留 `Hit/Miss` 两态。
- 常态移动与音游模式必须共享同一节拍主时钟。
- 与节拍相关的刷怪、输入判定、结算触发都应基于统一拍点时间轴。
