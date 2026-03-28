class_name SpawnChart
extends Resource
## 出怪谱面：定义多个波次，每波包含一组出怪记录
##
## EnemySpawner 在前一波结束并经过间隔拍后，从 waves 中随机选取下一波执行。
## 每条 SpawnEntry 的 beat 是相对于该波次开始时间的偏移拍。

## 波次列表（每个 SpawnWave 包含一组 SpawnEntry）
@export var waves: Array[SpawnWave] = []
## 本谱面的一波结束后等待多少拍再开始下一波
@export var next_wave_interval: int = 4
