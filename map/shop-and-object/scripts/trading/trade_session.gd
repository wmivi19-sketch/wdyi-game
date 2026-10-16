class_name TradeSession
extends RefCounted
var trade_id: String
var player_a: String
var player_b: String
var offers_a: Dictionary = {}
var offers_b: Dictionary = {}
var locked_a: bool = false
var locked_b: bool = false
var completed: bool = false
var cancelled: bool = false
var timeout_timer: float
## 设置或删除一方报价；count 为最终报价数量，0 表示删除。
func add_offer(player: String, item_id: String, count: int) -> void:
 if completed or cancelled or count < 0 or player not in [player_a, player_b]: return
 var item := ItemDatabase.get_item(item_id)
 if item == null or not item.is_tradeable or item.is_bound: return
 var offer := offers_a if player == player_a else offers_b
 if count == 0: offer.erase(item_id)
 else: offer[item_id] = count
 locked_a = false
 locked_b = false
## player 必须是参与者；锁定当前报价。
func lock_offer(player: String) -> void:
 if completed or cancelled: return
 if player == player_a: locked_a = true
 elif player == player_b: locked_b = true
## 双方锁定后交给管理器原子交换；无参数。
func confirm_trade() -> bool:
 return TradeManager.complete_trade(trade_id)
## 取消交易并释放会话；无参数。
func cancel_trade() -> void:
 TradeManager.cancel_session(trade_id)
