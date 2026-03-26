class_name PickupItem
extends GridEntity2D
## 拾取物：放置在网格上，玩家踩上去即可拾取
##
## 由网格系统判断玩家与拾取物的位置重叠，拾取后发出信号并自动销毁。

# ── 信号 ──────────────────────────────────────────────
## 被拾取时发出，携带拾取物自身引用
signal picked_up(item: PickupItem)

# ── 公开方法 ─────────────────────────────────────────

## 执行拾取：发出信号并销毁自身（由外部网格判定后调用）
func do_pickup() -> void:
	picked_up.emit(self)
	remove_and_free()
