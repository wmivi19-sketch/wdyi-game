---
name: hd2d-map-transition
description: 为八方旅人风格的 HD-2D 游戏设计自然的地图与场景过渡，处理像素精灵与 3D 场景的接缝、遮挡、景深过渡、光照统一和材质混合。适用于过渡设计与故障排查，提供 Unity 和 Unreal 实现。
---

# HD-2D 游戏地图自然过渡设计指南

用于回答 HD-2D 游戏跨地图、跨场景或跨区域时的视觉连续性问题。触发示例包括「从村庄走进树林时阴影突然变了」「像素角色上桥时脚底浮空」「八方旅人风格的室内外怎么平滑过渡」。普通地图加载、纯 2D 换图或单张地图的素材制作只有涉及这些 HD-2D 表现问题时才适用。

## 1. 诊断 HD-2D 特有的过渡问题

先从现有项目或描述确认引擎、渲染管线、相机投影、切换方式和最明显的症状。信息不足时，先用「同一相机穿过两块连续地形」给出可执行方案，注明示例的渲染管线。按症状定位并给出能在编辑器里复现和检查的步骤。

| 症状 | 优先检查 |
| --- | --- |
| 2D 精灵在 3D 地形上浮空、陷入地面或穿过栏杆 | 脚底枢轴、地面碰撞、精灵的深度测试与写入、透明对象排序 |
| 阳光方向、阴影边缘或环境色突然改变 | 区域主光、环境光、阴影配置、烘焙探针和自动曝光 |
| 角色跨线时瞬间失焦，或发丝边缘出现光晕 | DOF 模式、焦距参数覆盖、Volume 权重、精灵是否进入相机深度 |
| 精灵像素颗粒明显大于背景细节，移动时边缘闪烁 | 世界尺寸、屏幕像素比例、纹理过滤、背景高频细节和抗锯齿 |

## 2. 设计一段能双向穿越的过渡带

- **建立空间权重。** 在路径上放 A、B 两个锚点。设 `axis = B - A`，用 `t = clamp(dot(P - A, axis) / dot(axis, axis), 0, 1)` 映射进度，A 侧为 0，B 侧为 1。`P` 可取玩家脚点、相机或相机跟随目标。需要场景随玩家变化时取脚点，需要镜头随位置变化时取相机或跟随目标。先线性插值，再按画面需要对 `t` 两端缓动。过渡带长度按移速和目标时长定，例如 4 m/s 下 3 m 约为 0.75 秒。
- **平滑景深。** 两侧用同一种 DOF 模式，线性插值对焦距离、光圈或该模式的模糊参数，并让角色和交互物位于可读的焦区。对移动角色跟焦时用相机视空间深度，过滤焦点跳动。正交镜头先确认管线和平台支持的效果。正交与透视必须切换时，用窄门等遮挡点或镜头交叉淡入，并匹配角色平面的屏幕大小。相同视口下，Unity 的 `orthographicSize ≈ d × tan(垂直 FOV / 2)`，其中 `d` 是透视相机到角色平面的视空间深度。
- **统一光照。** 相邻地形共享主方向光的方向、交界处照度、环境光颜色及阴影柔和度。烘焙项目用一致的灯光、曝光和 Lightmap 设置，并检查跨区的动态物体探针。需要从冷光变暖光时，沿过渡带渐变同一盏可动主光的强度和颜色，或用门洞、屋檐、局部灯及色调过渡表达变化。保持投影方向和阴影过滤稳定，分别检查烘焙间接光与实时主光的接合。
- **用粒子贯穿接缝。** 用 Unity Particle System 或 Unreal Niagara 的世界空间薄雾、尘埃或光斑跨越边界，沿带状区域渐变密度或透明度。从远景放到中景，给角色轮廓和操作提示留出清晰区。软粒子或 `DepthFade` 可淡化贴地交线，先验证相机深度可用，再检查透明叠层、DOF 渲染顺序和开销。
- **衔接独立场景。** 两个区域不能同时显示时，用门廊、隧道或楼梯遮挡视线。先异步准备目标场景，沿用连续的相机姿态和角色屏幕尺寸，目标场景就绪后再揭开遮挡。流式加载时让过渡带两侧短暂共存，统一跨场景的主光和后处理控制器。

## 3. 对齐精灵、深度与地面材质

- **平滑脚点与 Z-depth。** 把视觉枢轴放到脚底，先接合可行走碰撞面，例如用桥坡连接两边高度。以真实地面为脚点，角色物理沿碰撞面移动，需要独立视觉贴地时在可行走层向下采样。只有近共面表面出现 Z-fighting 时才施加微小渲染偏移，可沿视线方向在过渡带用 `Lerp(深度偏移A, 深度偏移B, t)` 渐变。以相机空间的深度或地表法线确定偏移方向，并在镜头里确认脚底仍贴地。通过连续几何和渲染深度处理接缝，让深度缓冲记录每个像素的遮挡结果。
- **让深度测试处理 3D 遮挡。** Unity 用 `SpriteRenderer` 的 `Sorting Layer`、`Order in Layer` 与脚底 `Sprite Sort Point = Pivot` 管理透明精灵之间的顺序。Unreal 的 `Translucency Sort Priority` 同样用于透明对象。角色需要参与不透明遮挡、投影和 DOF 时，优先试带 Alpha Clip 或 Masked 的受光精灵材质，确认颜色、深度和阴影 pass 用一致的透明裁剪。可用受光四边形替代缺少对应 pass 的默认精灵材质。
- **在地表内部混合材质。** 用顶点色、地形层权重或线性空间控制图作为混合系数，对 Base Color、粗糙度或光滑度，以及同一切线空间的法线分别混合。法线混合后归一化。保留连续的不透明地表与深度写入，并匹配两侧的 UV 尺度、细节密度和表面高光。遮罩在 A 端为 0、B 端为 1，中间可以用草、石、道路或湿度分布打破直线。
- **固定资产 PPU，平滑调整显示比例。** 用 `可见像素高度 / 目标世界高度` 选基础 pixels-per-unit。角色尺寸一般保持固定，透视镜头自然产生近大远小。美术要求角色在变焦或镜头接力时保持近似屏幕高度，可只缩放以脚底为枢轴的视觉子节点。固定 FOV 下，透视补偿系数可从 `视空间深度 / 参考深度` 起步，限制范围并平滑。固定正交投影下移动相机远近本身不会改变像素大小，缩放补偿取决于正交视野尺寸。等效 PPU 为 `基础 PPU / 视觉缩放`。同步处理精灵帧和法线贴图，碰撞继续使用原世界尺寸。
- **让精灵响应 3D 主光。** 为角色手绘或从高度近似制作切线空间法线贴图，与颜色图保持帧、UV 和打包对齐。用支持法线的受光精灵材质或 3D Lit 四边形采样，使角色明暗随主光变化。用侧光检查法线通道方向、镜像和双面翻转，并以支持阴影的材质或地面接触阴影建立落地感。法线主要影响表面受光，投影轮廓由裁剪深度、阴影 pass 或独立投影代理提供。

## 4. Unity 实现示例（Unity 6，URP 17，Universal Renderer）

### Shader Graph 地表混合

1. 新建 `URP Lit Shader Graph`，保持 `Surface Type = Opaque`。把材质赋给跨越区域的地表网格，网格顶点色 R 从 A 侧 0 过渡到 B 侧 1。
2. 用两个 `Sample Texture 2D` 采样两侧颜色，`Vertex Color → Split.R → Saturate → Lerp.T`。采样结果接 `Lerp.A/B`，输出接 Fragment 的 `Base Color`。也可以用关闭 sRGB 的遮罩纹理代替顶点色。
3. 法线纹理按 Normal 类型采样，用同一权重 `Lerp → Normalize → Normal (Tangent Space)`。两侧的 Smoothness 同样插值。若项目使用原生 Unity Terrain，优先在 `Terrain Lit` 的 `Paint Texture` 中用 Terrain Layers 绘制权重。上面的普通网格 Shader Graph 用在地表网格上。

```text
Vertex Color.R -> Saturate -> Lerp.T
Sample BaseA.RGB -> Lerp.A
Sample BaseB.RGB -> Lerp.B
Lerp.Out -> Base Color
```

角色需要响应同一盏 3D 主光时，可用 `MeshRenderer` 四边形配 `URP Lit Shader Graph`，设为 `Opaque` 并开启 `Alpha Clipping`，把精灵纹理的 Alpha 接到 `Alpha` 输入。默认 `Sprite-Lit-Default` 面向 2D Renderer 的 `Light 2D`。

[Unity Shader Graph Lerp](https://docs.unity3d.com/Packages/com.unity.shadergraph@17.0/manual/Lerp-Node.html) · [Unity URP 2D 光照](https://docs.unity3d.com/cn/6000.0/Manual/urp/Lights-2D-intro.html)

### Volume 与 C# 联动

1. 游戏相机勾选 `Post Processing`，`Volume Mask` 包含场景 Volume 所在的层。在同一套相机 Volume 栈放两个 Global Volume。A 的 `Priority = 0`、`Weight = 1`，B 的 `Priority = 10`、`Weight = 0`。
2. 两个 Profile 均启用 `Depth Of Field`，透视相机示例勾选 `Mode` 覆盖并在两端均选 `Bokeh`。勾选参与混合的 `Focus Distance` 与 `Aperture`，两端的 `Focal Length` 使用同一值。B 的 Volume 权重对 A 与 B 的浮点覆盖值插值。主方向光设为 `Realtime`，共享方向和阴影过滤设置。
3. 将下面的组件保存为 `Hd2dZoneBlend.cs`。把脚点、两个锚点、B 的 Volume 和共用方向光拖入 Inspector，填写 A/B 的灯光端点。若灯光应该完全相同，两端填相同值。示例处理一组 A/B 区域，流式加载时让这组引用在过渡期间保持有效。卸载旧配置前先交接采样点、锚点和 Volume，避免空引用分支保留上一帧的混合状态。

```csharp
using UnityEngine;
using UnityEngine.Rendering;

public sealed class Hd2dZoneBlend : MonoBehaviour
{
    [SerializeField] private Transform samplePoint;
    [SerializeField] private Transform start;
    [SerializeField] private Transform end;
    [SerializeField] private Volume destinationVolume;
    [SerializeField] private Light sun;
    [SerializeField, Min(0f)] private float intensityA = 1f;
    [SerializeField, Min(0f)] private float intensityB = 1f;
    [SerializeField] private Color colorA = Color.white;
    [SerializeField] private Color colorB = Color.white;

    private void LateUpdate()
    {
        if (samplePoint == null || start == null || end == null ||
            destinationVolume == null || sun == null)
        {
            return;
        }

        Vector3 axis = end.position - start.position;
        float lengthSquared = axis.sqrMagnitude;
        if (lengthSquared < 0.000001f)
        {
            return;
        }

        float t = Mathf.Clamp01(
            Vector3.Dot(samplePoint.position - start.position, axis) / lengthSquared);

        destinationVolume.weight = t;
        sun.intensity = Mathf.Lerp(intensityA, intensityB, t);
        sun.color = Color.Lerp(colorA, colorB, t);
    }
}
```

镜头位置可以直接驱动后处理时，可用 A Global Volume 和 B Local Volume，给 B 添加 3D `Box Collider`，放在目标区并设 `Blend Distance`，`Weight` 保持 1。让相机或设定的 Volume Trigger 穿过混合范围。需要 DOF 与灯光严格共用一个线性空间权重时使用上面的 Global Volume 脚本，避免两种权重相乘。

[Unity URP Volume 参数](https://docs.unity3d.com/6000.0/Documentation/Manual/urp/volume-component-reference.html) · [Unity URP DOF 参数](https://docs.unity3d.com/6000.0/Documentation/Manual/urp/depth-of-field-volume-override-reference.html)

## 5. Unreal 实现示例（UE5，桌面透视相机）

### Material Editor 节点

1. 创建地表 Material，设 `Material Domain = Surface`、`Blend Mode = Opaque`、`Shading Model = Default Lit`。
2. 用两个 `TextureSampleParameter2D` 采样 A/B 纹理，接到 `LinearInterpolate.A/B`，将 `Vertex Color.R → Saturate` 接到 `Alpha`，输出接 `Base Color`。同一权重可用于 `Roughness` 与归一化后的 `Normal`。法线采样使用 Normal 类型。
3. 使用原生 Landscape 时，可用 `LandscapeLayerWeight` 将 A 接 `Base`、B 接指定图层的 `Layer`，在 Landscape Paint 中绘制该层权重；多个图层可用 `LandscapeLayerBlend`，需要覆在底层上的图层选 `LB Alpha Blend`。两侧共用材质坐标和涂绘尺度。

```text
TextureSampleParameter2D BaseA.RGB -> LinearInterpolate.A
TextureSampleParameter2D BaseB.RGB -> LinearInterpolate.B
Vertex Color.R -> Saturate -> LinearInterpolate.Alpha
LinearInterpolate -> Base Color
```

角色可用带法线的 Masked/Lit Paper 2D 材质或受光四边形。将贴图 Alpha 接 `Opacity Mask`，检查角色与桥栏的遮挡、投影轮廓和焦外边缘。Paper 2D 的 Pixels per unit 默认以厘米为世界单位换算。

[Unreal 材质表达式](https://dev.epicgames.com/documentation/en-us/unreal-engine/utility-material-expressions-in-unreal-engine) · [Landscape 材质](https://dev.epicgames.com/documentation/en-us/unreal-engine/landscape-material-expressions-in-unreal-engine) · [Paper 2D Sprite Editor](https://dev.epicgames.com/documentation/unreal-engine/paper-2d-sprite-editor-in-unreal-engine?lang=en-US)

### Post Process Volume 与蓝图事件

1. 配置两个 `Post Process Volume`。A 开启 `Infinite Extent (Unbound)`，`Priority = 0`，`Blend Weight = 1`。B 用更高的 `Priority`，如 10。两端都勾选 `Lens → Depth of Field → Focal Distance`，填入大于 0 的厘米值。UE 5.6 会对值为 0 的对焦距离作特殊处理，导致突变。用 `Cine Camera Actor` 时，可将 `Focus Method` 设为 `Manual`，用同一个 Alpha 插值 `Manual Focus Distance` 和 `Current Aperture`，并让相机负责 DOF，避免 Volume 和相机同时覆盖焦点。
2. 需要让相机自动过渡时，将 B 放到目标区，关闭 `Infinite Extent (Unbound)`，用 `Blend Radius` 设置外侧混合距离，`Blend Weight = 1`。默认 1 Unreal Unit 等于 1 cm，可用 300 对应 3 m 作为试调起点。以玩家为权重源且需联动主光时，开启 B 的 `Infinite Extent`，让蓝图写入 `Blend Weight`，初始为 0。主方向光设为 `Movable`。
3. 建 `BP_Hd2dZoneBlend`，添加覆盖过渡带的 `Box Collision`，`Collision Enabled = Query Only`，开启 `Generate Overlap Events`，只对 Pawn 通道设 `Overlap`。角色胶囊也开启 `Generate Overlap Events`。设置两个 `Target Point` 为 Start/End，公开 B Volume、方向光、两个灯光端点及跨带 Niagara 组件的引用，关闭 Niagara 的 `Auto Activate`。角色生成或重生时注册脚底 `Scene Component` 和胶囊，立即同步混合权重与粒子状态。之后持续按位置更新权重，支持半途折返或直接传送到另一侧。

```text
玩家注册（生成 / 重生） -> 设置 PlayerFoot、PlayerCapsule -> UpdateBlend
  -> Box.Is Overlapping Component(PlayerCapsule)
  -> Branch(True: Niagara.Activate, False: Niagara.Deactivate)
Event Tick -> UpdateBlend

Box.OnComponentBeginOverlap -> OtherComp == PlayerCapsule -> Niagara.Activate
Box.OnComponentEndOverlap   -> OtherComp == PlayerCapsule -> Niagara.Deactivate

UpdateBlend:
  IsValid(PlayerFoot、Start、End、B Volume、方向光组件) -> Branch
  Axis = End.GetActorLocation - Start.GetActorLocation
  LengthSquared = Dot Product(Axis, Axis)
  Branch(LengthSquared > 0.0001)
  Offset = PlayerFoot.GetWorldLocation - Start.GetActorLocation
  Alpha = Clamp(Dot Product(Offset, Axis) / LengthSquared, 0, 1)
  B Volume -> Set Blend Weight(Alpha)
  Directional Light Component -> Set Intensity(Lerp(IntensityA, IntensityB, Alpha))
  Tint = Lerp (LinearColor)(ColorA, ColorB, Alpha)
  Directional Light Component -> Set Light Color(Tint, SRGB = true)
```

Niagara 发射器应允许结束发射后让现有粒子自然消散。用场景中同一个常驻控制器写入共享灯光和后处理。门控淡入等定时演出可以用 `Timeline` 浮点轨道驱动 `Alpha`，通过 `Play` 和 `Reverse` 支持中途返回。

同一蓝图更新逻辑的 C++ 片段，可放在现有 Actor 的 `.cpp` 中，由 `BeginPlay` 和 `Tick` 传入已验证的组件引用和位置。

```cpp
#include "CoreMinimal.h"
#include "Components/DirectionalLightComponent.h"
#include "Engine/PostProcessVolume.h"

static void ApplyHd2dZoneBlend(
    const FVector& Sample, const FVector& Start, const FVector& End,
    APostProcessVolume& Destination, UDirectionalLightComponent& Sun,
    float IntensityA, float IntensityB,
    const FLinearColor& ColorA, const FLinearColor& ColorB)
{
    const FVector Axis = End - Start;
    const double LengthSquared = Axis.SizeSquared();
    if (LengthSquared <= 0.0001)
    {
        return;
    }

    const double Progress = FVector::DotProduct(Sample - Start, Axis) / LengthSquared;
    const float Alpha = static_cast<float>(FMath::Clamp(Progress, 0.0, 1.0));

    Destination.BlendWeight = Alpha;
    Sun.SetIntensity(FMath::Lerp(IntensityA, IntensityB, Alpha));
    Sun.SetLightColor(FMath::Lerp(ColorA, ColorB, Alpha), true);
}
```

[Unreal Post Process Volume](https://dev.epicgames.com/documentation/unreal-engine/post-process-effects-in-unreal-engine) · [Unreal Cinematic DOF](https://dev.epicgames.com/documentation/en-us/unreal-engine/cinematic-depth-of-field-in-unreal-engine) · [Unreal 蓝图灯光渐变](https://dev.epicgames.com/documentation/unreal-engine/fading-lights)

## 6. 快速检查清单

| 问题 | HD-2D 专属解法 | 验收方式 |
| --- | --- | --- |
| 精灵与地形脱节 | 确认脚底枢轴、碰撞和遮挡材质。用 `Sorting Layer` 调整精灵间顺序，近共面闪烁时用微小 Z 偏移 | 上下坡、进出门洞并从栏杆后经过，脚底和遮挡连续 |
| 光照方向突变 | 相邻区共用主光与环境。烘焙流程同步 Lightmap 和探针设置，实时 GI 流程同步天空、曝光与主光 | 让角色和地面阴影跨线，检查方向、亮度和边缘软硬 |
| 景深跳变 | Unity 用 Local Volume 的 `Blend Distance`，Unreal 用 `Blend Radius`，或由同一个空间权重控制 DOF | 慢走、冲刺、停在边界再折返，角色始终可读 |
| 像素锯齿明显 | 远处缩小时测试 Unity Sprite Atlas 的 `Generate Mip Maps` 或 Unreal 精灵纹理的 mipmap 与图集边距，再对照轻量后处理 AA，例如 Unity SMAA 或 Unreal FXAA | 在目标分辨率录制移动镜头，比较闪烁、串色、模糊和拖影，近景保留清晰像素边缘 |

## 7. 常见反模式

| 反模式 | 可执行修正 |
| --- | --- |
| 触发器内直接切换整个 lighting preset | 共用主光、曝光基准和阴影过滤，单独插值必要的实时属性 |
| 进区瞬间硬改 `Camera.orthographicSize`、`Ortho Width` 或 FOV | 匹配角色平面的投影尺寸，沿镜头轨迹过渡或把切换放到有效遮挡后 |
| 按距离逐帧重建 Sprite 来改变导入 PPU | 固定导入 PPU，优先调整镜头。需要补偿时从脚底平滑缩放视觉子节点 |
| 用大 Z 偏移或极端排序值修遮挡 | 从脚点、连续碰撞和深度 pass 定位原因，只在接近共面时使用微小偏移 |
| 两张半透明地板重叠淡入，或堆满粒子遮缝 | 在一张连续不透明地表上混合材质，用低密度的世界空间粒子辅助衔接 |
| 两个场景控制器同时写同一个光源或改动共享 Profile 资源 | 指定一个常驻控制器，播放时写 Volume 权重或独立实例的参数 |

输出优先给出最可能的原因、对应引擎的设置或片段，以及一项能观察到改善的验收方法。用户描述了场景时，具体到桥、坡道、门廊或树林边缘，并根据其引擎、相机和渲染管线选择示例。
