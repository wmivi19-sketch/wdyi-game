# 职业进阶与成神系统

独立 Godot 4.3+ / GDScript 示例。用编辑器导入本目录的 `project.godot`，按 F5 运行。
不会修改仓库中的 `map` 和 `zhushen-zhongyan` 项目。

## 演示

初始为战士 + 祭司，第 12 天夜晚，位于祭坛。点击合成获得法师印记，读条获得第三职业，随后可举行成神仪式。
模拟攻击按钮代表服务端已经确认的其他玩家攻击，造成伤害并打断仪式；模拟死亡移除神力和神明血量增益，保留职业。
打断不消耗印记，成功才消耗。成神不会自动回满 HP。

## 模块

- `resources/`：职业、配方、仪式条件、神明配置，可在编辑器创建 `.tres`。
- `systems/class_manager.gd`：服务端职业与仪式状态机，以及客户端 UI 状态缓存。
- `systems/progression_inventory.gd`：无信号的原子合成/扣除示例；不限制背包容量。
- `systems/ritual_altar.gd`：服务端祭坛登记、仪式白名单和交互距离。
- `systems/progression_player.gd`：玩家属性接口示例。
- `systems/time_manager.gd`：可替换的游戏内时钟示例，不自动推进时间。
- `demo/`：本地交互面板；不包含真实网络攻击请求或命中检测。
- `tests/run.gd`：可自动运行的核心回归测试。

## 规则

玩家最多三个不同职业，技能按 ID 去重。三职业未成神为半神。
普通最大 HP = 基础 HP + 职业 HP 加成。
神明最大 HP = 基础 HP × 神明倍率 + 职业 HP 加成 + 神明 HP 加成。
缺省基础 HP 为 100；移除神明时当前 HP 只向下截断，不回血。

仪式全程检查日期、时段、印记、前置职业、区域、祭坛距离和存活状态。
成神仅在第 12～14 天，跨入第 15 天未完成即失败。
仪式开始时保存条件快照；对局期间职业和神明注册表应保持只读。
提交阶段禁止打断，扣除和状态修改不调用外部信号；移除活动记录后才更新角色、发出事件。

## 接入已有项目

1. 复制 `resources/` 和 `systems/`，配置 TimeManager、ClassManager 两个 Autoload。
2. 用实际游戏时钟替换 TimeManager，保持 `get_current_day()` / `get_current_phase()`。
3. 服务端生成玩家后调用 `register_player()`，注册祭坛到 `ClassManager.altars`。
4. 玩家 ID 示例采用网络 peer ID；现有游戏的玩家 0 或 AI ID 需要显式映射，不能直接混用。
5. 客户端调用 `start_ritual(ritual_id, altar_id)`。服务端从 RPC 发送者读取身份。
6. 角色坐标、区域、印记、HP 必须由服务端维护；战斗系统确认伤害后才调用 `apply_confirmed_damage()`。
7. `add_class_slot()` 仅供可信服务端初始化或管理用途。`ascend_to_deity()` 仅允许正在提交的匹配仪式调用。
8. UI 监听 `notice`、`ritual_started`、`ritual_ended`、`form_changed`；创建时可从 `replicated_forms` 和 `replicated_rituals` 恢复界面。
9. 所有客户端均加载同路径 Autoload，服务端收到客户端场景就绪通知后调用 `send_snapshot(peer_id)`。
10. 断开连接时调用 `unregister_player()`；持久化与账号重连恢复由宿主项目实现。

真实多人接入还需要宿主项目提供网络会话、服务端命中判定、状态同步、RPC 请求限流和存档。本演示不把客户端按钮当作攻击权限。

## 验证

```shell
godot --headless --path class-progression --editor --quit
godot --headless --path class-progression --script res://tests/run.gd
```

第一条先生成全局类缓存。测试失败返回非零退出码。
