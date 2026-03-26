class_name EnemySpawner
extends Node2D
## 敌人生成器：按节拍在网格中生成敌人
##
## 支持两种模式：
## 1. 谱面模式：配置了 spawn_charts 时，按当前阶段索引从对应谱面的波次池中
##    随机选取一波执行，波次结束后等待 wave_interval 拍再随机选取下一波。
##    阶段由外部通过 set_stage() / next_stage() 切换。
## 2. 随机节拍模式：未配置谱面时，每隔 beats_per_spawn 个移动拍在最左列随机生成
##
## 监听 RhythmConductor 的 move_beat_tick 信号（lane 模式时不发出，
## 因此 lane 期间谱面自动冻结、出怪自动暂停）。

# ── 导出属性 ─────────────────────────────────────────
## 敌人场景资源列表（通过 SpawnEntry.enemy_index 索引）
@export var enemy_scenes: Array[PackedScene] = []
## 同时存在的最大敌人数量
@export var max_enemies: int = 5

@export_group("预警")
## 预警场景（为空时不显示预警，直接生成敌人）
@export var warn_scene: PackedScene
## 预警持续拍数（出怪前提前多少拍显示预警）
@export var warn_beats: int = 2

@export_group("谱面模式")
## 出怪阶段谱面列表（每个元素代表一个阶段的波次池，为空时使用随机节拍模式）
@export var spawn_charts: Array[SpawnChart] = []
## 前一波结束后等待多少拍再开始下一波
@export var wave_interval: int = 4

@export_group("随机节拍模式")
## 每隔多少个移动拍生成一个敌人（仅随机模式）
@export var beats_per_spawn: int = 4

# ── 内部变量 ─────────────────────────────────────────
## 当前阶段索引（对应 spawn_charts 中的下标）
var _current_stage: int = 0
## 移动拍计数器（仅统计 move_beat_tick，lane 模式期间不递增）
var _move_beat_count: int = 0
## 当前正在执行的波次（null 表示尚未开始或在等待间隔中）
var _current_wave: SpawnWave = null
## 当前波次开始时的全局移动拍号
var _wave_start_beat: int = 0
## 当前波次中最大的相对拍号（用于判断波次结束）
var _wave_max_beat: int = 0
## 波次结束时的全局移动拍号（用于计算间隔等待）
var _wave_end_beat: int = -1
## 待生成队列：存储预警中尚未到期的生成信息
## 每个元素为字典 { "grid_pos": Vector2i, "enemy_idx": int, "warning": SpawnWarning, "remaining_beats": int }
var _pending_spawns: Array[Dictionary] = []

## 网格系统引用（通过唯一名称获取）
@onready var _grid: GridSystem2D = %GridSystem2D
## 节拍指挥引用（通过唯一名称获取）
@onready var _conductor: RhythmConductor = %RhythmConductor

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	if _conductor != null:
		_conductor.move_beat_tick.connect(_on_move_beat_tick)
		_conductor.stage_advanced.connect(_on_stage_advanced)
	var mode_text: String = "谱面(%d阶段)" % spawn_charts.size() if not spawn_charts.is_empty() else "随机(每%d拍)" % beats_per_spawn
	CLog.o("EnemySpawner 就绪 | 模式=%s  最大数量=%d" % [mode_text, max_enemies])

# ── 信号回调 ─────────────────────────────────────────

## 收到移动节拍信号：延迟到帧末尾再生成，确保已有敌人先完成移动释放格子
func _on_move_beat_tick(_beat_index: int) -> void:
	_spawn_deferred.call_deferred()

## 收到阶段推进信号：同步切换出怪阶段
func _on_stage_advanced(stage_index: int) -> void:
	set_stage(stage_index)


## 延迟生成：在帧末尾根据模式决定是否生成敌人
func _spawn_deferred() -> void:
	# 先推进所有预警的剩余拍数
	_tick_pending_warnings()
	if _get_current_chart() != null:
		_process_chart_beat()
	else:
		_process_random_beat()
	_move_beat_count += 1

# ── 谱面模式 ─────────────────────────────────────────

## 谱面模式：管理波次的选取、执行和间隔等待
func _process_chart_beat() -> void:
	var chart: SpawnChart = _get_current_chart()
	if chart == null or chart.waves.is_empty():
		return
	# 如果没有正在执行的波次，尝试开始新波次
	if _current_wave == null:
		# 首次或等待间隔结束后开始新波次
		if _wave_end_beat < 0 or _move_beat_count >= _wave_end_beat + wave_interval:
			_start_random_wave()
		return
	# 当前波次正在执行：计算相对拍号并生成对应敌人
	var relative_beat: int = _move_beat_count - _wave_start_beat
	for entry: SpawnEntry in _current_wave.entries:
		if entry.beat == relative_beat:
			_spawn_at_pos(entry.pos, entry.enemy_index)
	# 检查波次是否已结束
	if relative_beat >= _wave_max_beat:
		CLog.o("波次结束（持续 %d 拍）" % (_wave_max_beat + 1))
		_wave_end_beat = _move_beat_count
		_current_wave = null


## 从当前阶段谱面的波次列表中随机选取一波并开始执行
func _start_random_wave() -> void:
	var chart: SpawnChart = _get_current_chart()
	var wave_index: int = randi() % chart.waves.size()
	_current_wave = chart.waves[wave_index]
	_wave_start_beat = _move_beat_count
	# 计算该波次中最大的相对拍号
	_wave_max_beat = 0
	for entry: SpawnEntry in _current_wave.entries:
		if entry.beat > _wave_max_beat:
			_wave_max_beat = entry.beat
	CLog.o("开始波次 #%d（共 %d 条记录，最大拍 %d）" % [wave_index, _current_wave.entries.size(), _wave_max_beat])
	# 立即处理第 0 拍的出怪记录
	for entry: SpawnEntry in _current_wave.entries:
		if entry.beat == 0:
			_spawn_at_pos(entry.pos, entry.enemy_index)

# ── 随机节拍模式 ─────────────────────────────────────

## 随机模式：每隔 beats_per_spawn 拍在最左列随机行生成
func _process_random_beat() -> void:
	if _move_beat_count % beats_per_spawn != 0:
		return
	_spawn_one_random()

# ── 生成逻辑 ─────────────────────────────────────────

## 判断格子是否可用于生成敌人（无空气墙且无玩家占用，允许有拾取物）
func _is_spawnable(grid_pos: Vector2i) -> bool:
	if not _grid.is_cell_empty(grid_pos, GridEntity2D.LAYER_WALL):
		return false
	return _grid.is_cell_empty(grid_pos, GridEntity2D.LAYER_PLAYER)


## 在指定网格位置生成指定种类的敌人（带预警）
func _spawn_at_pos(grid_pos: Vector2i, enemy_idx: int) -> void:
	if enemy_scenes.is_empty() or _grid == null:
		return
	if _is_over_limit():
		return
	var scene: PackedScene = _get_enemy_scene(enemy_idx)
	if scene == null:
		CLog.o("EnemySpawner enemy_index=%d 超出范围（共 %d 种）" % [enemy_idx, enemy_scenes.size()])
		return
	# 有预警场景且预警拍数 > 0 时，先显示预警
	if warn_scene != null and warn_beats > 0:
		_spawn_warning(grid_pos, enemy_idx)
	else:
		# 无预警，直接生成（需检查格子可用性）
		if not _is_spawnable(grid_pos):
			CLog.o("EnemySpawner 无法在 %s 生成（格子不可用）" % grid_pos)
			return
		_do_spawn(grid_pos, scene)


## 在最左列随机行生成敌人
func _spawn_one_random() -> void:
	if enemy_scenes.is_empty() or _grid == null:
		return
	if _is_over_limit():
		return
	# 获取所有有效格子，找到最左列
	var all_cells: Array[Vector2i] = _grid.get_all_cells()
	if all_cells.is_empty():
		return
	var min_x: int = _get_min_x()
	if min_x == -1:
		return
	# 筛选最左列中可用于生成的格子
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in all_cells:
		if cell.x == min_x and _is_spawnable(cell):
			candidates.append(cell)
	if candidates.is_empty():
		return
	var grid_pos: Vector2i = candidates[randi() % candidates.size()]
	# 随机模式也支持预警
	if warn_scene != null and warn_beats > 0:
		_spawn_warning(grid_pos, 0)
	else:
		_do_spawn(grid_pos, enemy_scenes[0])


## 执行实际的敌人实例化和放置
func _do_spawn(grid_pos: Vector2i, scene: PackedScene) -> void:
	var world_pos: Vector2 = _grid.grid_to_world(grid_pos)
	var enemy: Enemy = scene.instantiate() as Enemy
	enemy.position = world_pos
	enemy.add_to_group("enemies")
	add_child(enemy)
	# 修正 owner 为场景根节点，使 % 唯一名称可用
	enemy.owner = owner
	# 在网格系统中注册敌人占用（place_entity 内部会调用 _on_placed，完成信号连接等初始化）
	_grid.place_entity(grid_pos, enemy)
	CLog.o("生成敌人 -> %s（移动拍 #%d）" % [grid_pos, _move_beat_count])

# ── 预警逻辑 ─────────────────────────────────────────

## 在指定位置生成预警提示，剩余拍数由 _tick_pending_warnings 递减
func _spawn_warning(grid_pos: Vector2i, enemy_idx: int) -> void:
	var world_pos: Vector2 = _grid.grid_to_world(grid_pos)
	var warning: SpawnWarning = warn_scene.instantiate() as SpawnWarning
	warning.position = world_pos
	add_child(warning)
	# 记录待生成信息（含剩余拍数）
	var spawn_info: Dictionary = {
		"grid_pos": grid_pos,
		"enemy_idx": enemy_idx,
		"warning": warning,
		"remaining_beats": warn_beats,
	}
	_pending_spawns.append(spawn_info)
	CLog.o("预警显示 -> %s（%d 拍后生成）" % [grid_pos, warn_beats])


## 每个移动拍推进所有预警的剩余拍数，到 0 时实际生成敌人
func _tick_pending_warnings() -> void:
	# 倒序遍历，方便安全移除
	var i: int = _pending_spawns.size() - 1
	while i >= 0:
		var info: Dictionary = _pending_spawns[i]
		info["remaining_beats"] = (info["remaining_beats"] as int) - 1
		if (info["remaining_beats"] as int) <= 0:
			_pending_spawns.remove_at(i)
			_resolve_warning(info)
		i -= 1


## 预警倒计时结束，结束预警节点并尝试实际生成敌人
func _resolve_warning(spawn_info: Dictionary) -> void:
	# 结束预警视觉效果
	var warning: SpawnWarning = spawn_info["warning"] as SpawnWarning
	if warning != null and is_instance_valid(warning):
		warning.finish()
	var grid_pos: Vector2i = spawn_info["grid_pos"] as Vector2i
	var enemy_idx: int = spawn_info["enemy_idx"] as int
	if _is_over_limit():
		CLog.o("预警结束但超出上限，取消生成 %s" % grid_pos)
		return
	if not _is_spawnable(grid_pos):
		CLog.o("预警结束但格子不可用，取消生成 %s" % grid_pos)
		return
	var scene: PackedScene = _get_enemy_scene(enemy_idx)
	if scene == null:
		return
	_do_spawn(grid_pos, scene)

# ── 辅助方法 ─────────────────────────────────────────

## 检查当前敌人数量是否超过上限
func _is_over_limit() -> bool:
	var current_count: int = get_tree().get_nodes_in_group("enemies").size()
	return current_count >= max_enemies


## 获取网格最左列的 X 坐标，无有效格子时返回 -1
func _get_min_x() -> int:
	var all_cells: Array[Vector2i] = _grid.get_all_cells()
	if all_cells.is_empty():
		return -1
	var min_x: int = all_cells[0].x
	for cell: Vector2i in all_cells:
		if cell.x < min_x:
			min_x = cell.x
	return min_x


## 根据索引获取敌人场景，越界时返回 null
func _get_enemy_scene(idx: int) -> PackedScene:
	if idx < 0 or idx >= enemy_scenes.size():
		return null
	return enemy_scenes[idx]


## 获取当前阶段的出怪谱面，无有效阶段时返回 null
func _get_current_chart() -> SpawnChart:
	if spawn_charts.is_empty() or _current_stage < 0 or _current_stage >= spawn_charts.size():
		return null
	return spawn_charts[_current_stage]

# ── 阶段控制（外部调用） ──────────────────────────────

## 设置当前阶段索引，并重置波次状态
func set_stage(stage_index: int) -> void:
	if stage_index < 0 or stage_index >= spawn_charts.size():
		CLog.o("EnemySpawner set_stage 索引越界: %d（共 %d 阶段）" % [stage_index, spawn_charts.size()])
		return
	_current_stage = stage_index
	_reset_wave_state()
	CLog.o("EnemySpawner 切换到阶段 #%d" % stage_index)


## 推进到下一个阶段，已在最后阶段时不做操作
func next_stage() -> void:
	set_stage(_current_stage + 1)


## 重置波次状态（切换阶段时调用）
func _reset_wave_state() -> void:
	_current_wave = null
	_wave_end_beat = -1
