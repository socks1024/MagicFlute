class_name FallingNote
extends ColorRect
## 单个下落音符
##
## 由 RhythmLane 动态实例化并管理位置，
## 自身只存储数据和引用子节点。

## 所在轨道索引
var lane_index: int = 0
## 对应的节拍索引
var beat_index: int = 0

## 按键标签引用
@onready var label: Label = $Label
