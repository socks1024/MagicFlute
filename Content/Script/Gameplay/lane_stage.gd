class_name LaneStage
extends Resource
## 轨道序列阶段：定义一个游戏阶段内的所有 lane 音符序列
##
## 每个 LaneStage 代表一个游戏阶段，包含若干段音符序列。
## 玩家每次触发 lane 模式时消费一段序列，
## 本阶段所有序列用完后自动推进到下一阶段。

## 本阶段的音符序列列表（每个 LaneSequence 代表一次 lane 触发的方向序列）
@export var sequences: Array[LaneSequence] = []
