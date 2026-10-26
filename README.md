# 逐神终焉

正式Godot工程位于[`map/project.godot`](map/project.godot)。在Godot编辑器打开后按F5，从原主菜单开始游戏。新游戏先进入独立的三层烛井新手关，完成后进入原六大陆；职业、共享背包、战斗与存档沿用正式系统。

烛井采用2D像素斜俯视与人物跟随镜头，中央圆弧石梯连续贯通三层，天窗回落中层隐藏室。WASD/方向键按屏幕方向移动，空格跳跃，E交互，F5保存，F10保存回菜单。

当前使用Godot4.7.2验证。命令行从仓库根运行：

```sh
godot --headless --editor --path map --quit
godot --path map
```

新手关实现与地图坐标见[楼梯说明](map/tutorial/continuous_well/README.md)，验证结果见[代码检查记录](map/CODE_REVIEW.md)。`zhushen-zhongyan`为已有独立调试工程，完整游戏入口以map工程为准。

缓存、验证截图、运行日志和本地备份均不提交。首次克隆后由Godot自动生成导入缓存。

## 艾兰瑟大陆地图

[艾兰瑟大陆地图 · 四镇平原 v10](maps/ailanse-continent/README.md) 已保存为独立 Godot 4.5.2 地图工程，包含葡萄酿酒、酒港贸易、麦作磨坊与亚麻纺织四镇，以及素材、实机预览和验证记录。整图暂按 1000×1000 米制作。

用 Godot 导入 `maps/ailanse-continent/project.godot` 后按 F5 运行。该地图尚未接入正式游戏菜单、战斗和存档。

## HD-2D 教堂与人物测试

[教堂场景项目](hd2d-cathedral/README.md)包含可复用元素模板、90个教堂场景元素，以及支持移动、跳跃和更换贴图的测试人物。使用 Godot 4.7.2 导入 `hd2d-cathedral/project.godot` 后按 F5 运行。
