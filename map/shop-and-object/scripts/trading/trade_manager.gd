extends Node
signal trade_created(trade_id: String)
signal trade_completed(trade_id: String)
signal trade_cancelled(trade_id: String)
var config: Dictionary = {}
var sessions: Dictionary = {}
var players: Dictionary = {}
var locations: Dictionary = {}
var serial: int = 0
## 加载交易配置；无参数。
func _ready() -> void:
 reload()
## 热重载配置；既有会话将在提交时使用新规则。
func reload() -> void:
 var next := Config.read_json("res://shop-and-object/resources/trading/trade_config.json")
 if next.has_all(["trade_days","trade_hours","exchange_locations","currency_item_id","trade_timeout_seconds"]): config = next
## 由可信服务器注册玩家背包及地点；id 是服务器玩家 ID。
func register_player(id: String, inventory: Inventory, location: String) -> void:
 players[id] = inventory
 locations[id] = location
## 检查交易日期、小时和地点。
func can_trade(current_day: int, current_hour: int, location: String) -> bool:
 if config.is_empty(): return false
 return config.trade_days.any(func(day): return int(day) == current_day) and current_hour >= config.trade_hours.start and current_hour < config.trade_hours.end and location in config.exchange_locations
## 检查双方在同一交易所；a、b 为玩家 ID。
func eligible(a: String, b: String) -> bool:
 if not players.has(a) or not players.has(b) or players[a] == players[b]: return false
 var place := str(locations.get(a, ""))
 return place == str(locations.get(b, "")) and can_trade(GameState.current_day, GameState.minutes(GameState.current_time) / int(Config.data.minutes_per_hour), place)
## 创建会话；无效参与者、已有会话或不在交易窗口返回空字符串。
func create_trade_session(player_a: String, player_b: String) -> String:
 if player_a == player_b or not eligible(player_a, player_b): return ""
 for active in sessions.values():
  if player_a in [active.player_a, active.player_b] or player_b in [active.player_a, active.player_b]: return ""
 serial += 1
 var session := TradeSession.new()
 session.trade_id = str(serial)
 session.player_a = player_a
 session.player_b = player_b
 session.timeout_timer = float(config.trade_timeout_seconds)
 sessions[session.trade_id] = session
 trade_created.emit(session.trade_id)
 return session.trade_id
## 查询活动会话；trade_id 为会话 ID。
func get_active_session(trade_id: String) -> TradeSession:
 return sessions.get(trade_id)
## 验证报价数据和所有权；offer 来自不可信调用方时同样校验。
func valid_offer(offer: Dictionary, inventory: Inventory) -> bool:
 for id in offer:
  var item := ItemDatabase.get_item(id)
  if not (offer[id] is int) or offer[id] <= 0 or item == null: return false
  if item.is_bound or not item.is_tradeable or not inventory.has_item(id, offer[id]): return false
 return true
## 构造净交换快照；own 为付出，other 为收到。
func exchanged(inventory: Inventory, own: Dictionary, other: Dictionary) -> Dictionary:
 var next := inventory.snapshot()
 for id in own: next[id] = int(next.get(id, 0)) - int(own[id])
 for id in other: next[id] = int(next.get(id, 0)) + int(other[id])
 return next
## 无 await 的双背包提交，任一校验失败则双方保持原样。
func complete_trade(trade_id: String) -> bool:
 var s := get_active_session(trade_id)
 if s == null or s.completed or s.cancelled or not s.locked_a or not s.locked_b or s.timeout_timer <= 0: return false
 if not eligible(s.player_a, s.player_b): return false
 var a: Inventory = players[s.player_a]
 var b: Inventory = players[s.player_b]
 if not valid_offer(s.offers_a, a) or not valid_offer(s.offers_b, b): return false
 var next_a := exchanged(a, s.offers_a, s.offers_b)
 var next_b := exchanged(b, s.offers_b, s.offers_a)
 if not a.fits(next_a) or not b.fits(next_b): return false
 a.commit(next_a, false)
 b.commit(next_b, false)
 s.completed = true
 sessions.erase(trade_id)
 a.publish()
 b.publish()
 trade_completed.emit(trade_id)
 return true
## 取消指定会话，确保取消信号只发送一次。
func cancel_session(trade_id: String) -> void:
 var s := get_active_session(trade_id)
 if s == null: return
 s.cancelled = true
 sessions.erase(trade_id)
 trade_cancelled.emit(trade_id)
## 累计真实帧耗时并自动取消超时会话；delta 为秒。
func _process(delta: float) -> void:
 for id in sessions.keys():
  var s: TradeSession = sessions[id]
  s.timeout_timer -= delta
  if s.timeout_timer <= 0: cancel_session(id)
