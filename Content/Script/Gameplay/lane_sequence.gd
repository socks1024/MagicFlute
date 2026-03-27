class_name LaneSequence
extends Resource
## 单段轨道音符序列：记录一次 lane 触发时依次出现的方向
##
## 在编辑器检查器中可通过下拉框选择上/下/左/右。

## 方向枚举（与 RhythmConductor 中的轨道索引一一对应）
enum Direction {
	UP = 0,    ## 上（W）→ lane 0
	LEFT = 1,  ## 左（A）→ lane 1
	DOWN = 2,  ## 下（S）→ lane 2
	RIGHT = 3, ## 右（D）→ lane 3
}

## 本序列的方向列表
@export var notes: Array[Direction] = []

##序列对应的音乐
@export var Playmusic:AudioEvent 
