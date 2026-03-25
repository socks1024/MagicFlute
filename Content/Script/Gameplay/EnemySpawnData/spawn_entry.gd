class_name SpawnEntry
extends Resource
## 单条出怪记录：定义一个敌人的生成时机、位置和种类

## 相对于波次开始的第几拍时生成（从 0 开始计数）
@export var beat: int = 0
## 生成在哪个网格位置
@export var pos: Vector2i = Vector2i.ZERO
## 敌人种类索引（对应 EnemySpawner.enemy_scenes 数组下标）
@export var enemy_index: int = 0
