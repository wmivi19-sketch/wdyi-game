# Persona 风格紧凑三行动态 UI / Godot 4.x

左上角三行 HP / SP（体力）/ MP，红、黄绿、蓝配色。每行 22px 高，行间距 3px，整体默认 340×72，屏幕边距 24px；实际彩色条身仅 14px 高。标签在左侧，数值在右侧固定列。图形无需外部素材，全部由 Control、ColorRect 与 ShaderMaterial 生成。

## 运行完整演示

用 Godot 4.x 打开本目录 `project.godot`，按 F5。1 扣血、2 消耗体力、3 消耗蓝量、R 回满，也可以点击按钮。此工程为完整的独立 UI 演示；《逐神终焉》完整游戏仍从上级 `map/project.godot` 启动，保留正式封面、菜单和地图。本组件已经接入正式地图。

```powershell
godot --path .
godot --headless --path . --script res://tests/test_vitals.gd
```

## 场景、脚本与资源

- `scenes/vitals_hud.tscn`：Control + VBoxContainer + 三个状态行。
- `scripts/vitals_hud.gd`：统一更新接口与减少动态效果设置。
- `scenes/vital_bar.tscn`、`scripts/vital_bar.gd`：单行资源显示，负责真实条宽、数字和 Tween。
- `shaders/fluid.gdshader`：斜切蒙版、渐变、扫光、锐利边框和低值警告。
- `scenes/demo.tscn`、`scripts/demo.gd`：CanvasLayer 下的可交互演示。
- `tests/test_vitals.gd`：29 项检查，涵盖比例、几何宽度、动画中断、零值、缩放及异常输入。
- `tests/capture_preview.gd`：实际图形渲染截图工具，输出 `tests/three-row-preview.png`。截图脚本需图形模式，不能添加 `--headless`。

```text
CanvasLayer
└─ VitalsHUD (Control, 340×72)
   └─ Bars (VBoxContainer, separation=3)
      ├─ HP (Control, height=22)
      ├─ Stamina / SP (Control, height=22)
      └─ MP (Control, height=22)

每行：Label | 警告符号 | ColorRect 动态条身 | 当前值/最大值
```

## 真正伸缩的长度公式

```text
基准宽度 B = 行宽 − 标签区 44px − 文本间隔 8px − 数值区 76px
目标比例 R = clamp(当前值 / 最大值, 0, 1)
实际 ColorRect 宽度 = B × 动画显示比例
```

默认行宽 340px，因此 B=212px。HP 为 85/100 时，动画最终条宽为 180.2px。三行使用相同基准宽度，各自独立伸缩，彼此不分配或抢占宽度。

Tween 不只改变固定长框内部的填充：它直接改变 ColorRect 的实际宽度，所以彩色背景、斜切轮廓、流光和边框一起缩短或延长，条尾不保留固定宽度的空框。数值为零时条身完全隐藏，同时仍显示标签、0/最大值和低值警告。

数值标签固定在右侧，避免跟随条尾移动造成阅读跳动。改变 HUD 根节点宽度会自动重算基准宽度，建议使用 260–340px；最低支持 200px。字体 12px，数值区 76px，超长数值需要加宽文本区或减小字号。

## 数据更新接口

在其他项目中，将整个目录复制到项目内，再把 `scenes/vitals_hud.tscn` 实例化到 CanvasLayer 下。内部资源使用相对引用。CanvasLayer 保持屏幕位置固定，所有行都忽略鼠标，不阻挡游戏交互。

```gdscript
# 场景已加入树并 ready 后调用：
$CanvasLayer/VitalsHUD.update_vitals(85, 100, 16, 100, 41, 100)

# 初始化/读档：最后的 true 表示立即同步。
$CanvasLayer/VitalsHUD.update_vitals(100, 100, 80, 100, 60, 100, true)

# 也可单独更新一行：
$CanvasLayer/VitalsHUD.hp.set_value(35, 100)

# 调整宽度：基准宽度及所有条的真实长度会重新计算。
$CanvasLayer/VitalsHUD.size.x = 300

# 随时停用动态效果，并立即显示最终数值。
$CanvasLayer/VitalsHUD.reduced_motion = true
```

默认 `create_tween()` 使用 0.45 秒 cubic ease-out，同时过渡数字与实际条长。连续更新会停止旧 Tween，从当前可见比例继续，相同目标不重启动画。单行 `set_value` 支持 ready 前初始化；统一 `update_vitals` 在 ready 后调用。

负数和超上限输入会钳制；零/负/非有限最大值显示空条且不报警；NaN 等非法当前值按零处理。最大值降低时显示数字不会临时超过新上限。

## 警告与视觉调整

每行当前值严格低于最大值的 20% 时，该行变暗、边框闪动，并在标签旁显示静态 `!`。正好 20% 不报警。零值时即使条身已消失，警告符号仍在；其他行不会被影响。

单行 Inspector 可调整 `caption`、`accent`、`warning_ratio`、`transition_seconds`。HUD 的 `reduced_motion` 会立即传播到三行，停止 Tween、扫光和闪烁，同时保留静态颜色与 `!`。

默认使用 Godot 内置无衬线字体。自定义字体可将有授权的 Noto Sans / 思源黑体 `.ttf` 或 `.otf` 放入新建的 `assets/fonts/`，建立 Theme，设置 Default Font 并赋给 HUD 根节点。单行标签继承字体。

所有图形是原创程序图形，未使用官方 Persona 图像、商标、音频或字体。ColorRect 的 ShaderMaterial 根据 UV 裁切斜边，计算纵向渐变、移动高光和细边框，每行独立材质。已在 Godot 4.7.2 Compatibility / OpenGL 实际渲染验证。

## 正式游戏接入

`shop-and-object/scripts/integration/world_items.gd` 自动创建 `fluid_vitals.gd`，绑定 GameManager 的真人资源变化信号。该适配器不修改战斗属性、职业、背包、碰撞或存档。旧状态条隐藏，原技能按钮、目标和冷却信息保留；顶部操作说明与大陆选择器位于三行 HUD 下方。打开人物面板或地图时隐藏，关闭后恢复，切图及读档后立即同步。

在 map 目录运行：

```powershell
godot --headless --path . --script res://shop-and-object/tests/test_fluid_vitals_integration.gd
godot --headless --path . --script res://shop-and-object/tests/test_game_radial.gd
```
