class_name SpawnWave
extends Resource
## 一波出怪记录：包含一组 SpawnEntry，每条记录的 beat 是相对于波次开始的偏移拍

## 该波次包含的出怪记录列表
@export var entries: Array[SpawnEntry] = []
