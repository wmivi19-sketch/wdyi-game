"""Build editable Godot instances using the reference's 1672 x 941 composition.

The PNG cutouts are camera-aligned 3D cards, with roots on the floor or their
supporting surfaces. All final transforms are baked into cathedral.tscn.
Run from the project root. This never modifies the original PNG files.
"""
from pathlib import Path
import json
import math

ROOT = Path(__file__).resolve().parents[1]
META = json.loads((ROOT / 'docs/asset_inventory.json').read_text(encoding='utf-8'))
W, H = 1672, 941
ANGLE = math.radians(28)
S, C = math.sin(ANGLE), math.cos(ANGLE)
T = math.tan(math.radians(45) / 2)
CAM = (0, 18, 32)

def asset(code, version=None):
    choices = [p for p in META if Path(p).name.startswith(code + '_')]
    if version:
        return next(p for p in choices if p.endswith('-' + version + '.png'))
    return next(p for p in choices if '-' not in Path(p).stem)

def ground_depth(screen_y, elevation=0):
    up = (1 - 2 * screen_y / H) * T
    return (CAM[1] - elevation) / (S - up * C)

def position(x, y, depth):
    right = (2*x/W - 1) * T * W/H * depth
    up = (1-2*y/H) * T * depth
    return (right, CAM[1] - S*depth + C*up, CAM[2] - C*depth - S*up)

def vec(v):
    return ', '.join(f'{n:.7f}' for n in v)

items = []
def add(name, code, rect, group, version=None, depth=None, elevation=0, collision=2, flip=False):
    x,y,w,h = rect
    if depth is None:
        depth = ground_depth(y+h, elevation)
    p = asset(code, version)
    bbox = META[p]['bbox']; bw=bbox[2]-bbox[0]; bh=bbox[3]-bbox[1]
    units = 2*depth*T/H
    items.append(dict(name=name, path=p, group=group, rect=rect, depth=depth,
        pos=position(x+w/2,y+h,depth), pixel=units*w/bw,
        scale_y=(h/bh)/(w/bw), collision=collision, flip=flip))

# Architecture extends beyond the frame, as in the supplied image.
wall_depth = ground_depth(445)
add('Apse_BackWall','A01',(360,-155,952,600),'Architecture',depth=wall_depth)
add('Left_AisleWall','A02',(-420,-150,1010,790),'Architecture',depth=wall_depth+1)
add('Right_AisleWall','A03',(1082,-150,1010,790),'Architecture',depth=wall_depth+1)
add('Left_VaultArch','A04',(-70,-280,640,530),'Architecture',version='v2',depth=wall_depth-1)
add('Right_VaultArch','A04',(1102,-280,640,530),'Architecture',version='v2',depth=wall_depth-1)

# Three high stained-glass windows and glimpses into the side aisles.
for name,code,rect in [('Left','A11',(586,-112,110,292)),('Center','A12',(775,-155,122,335)),('Right','A13',(976,-112,110,292))]:
    add('ApseWindow_'+name,code,rect,'Windows',depth=wall_depth-0.3)
add('SideWindow_Left','A14',(-28,135,76,252),'Windows',depth=wall_depth-0.5)
add('SideWindow_Right','A15',(1624,135,76,252),'Windows',depth=wall_depth-0.5)

# Six colonnade pillars establish the front / middle / rear rhythm.
for name,code,rect,version in [
    ('Rear_Left','A09',(384,-85,92,527),'v2'),('Rear_Right','A10',(1196,-85,92,527),None),
    ('Middle_Left','A07',(187,-220,142,829),'v2'),('Middle_Right','A08',(1343,-220,142,829),None),
    ('Front_Left','A05',(-28,-230,220,1010),'v2'),('Front_Right','A06',(1480,-230,220,1010),None)]:
    add('Pillar_'+name,code,rect,'Columns',version,collision=1)

# Sanctuary platform, stair facade and central icon ensemble.
add('Sanctuary_Steps','A20',(382,431,908,67),'Altar',version='v2',collision=2)
altar_depth = ground_depth(407, 2.8)
add('Altar_Rug','F51',(744,400,184,34),'Altar',depth=altar_depth-0.05)
add('Central_Shrine','F49',(779,147,114,210),'Altar',depth=altar_depth+0.35)
add('Red_Robed_Icon','F47',(815,235,42,82),'Altar',depth=altar_depth+0.15)
add('Altar_Table','F48',(740,324,192,84),'Altar',version='v1',depth=altar_depth-0.1,collision=1)
add('Gold_Monstrance','F50',(819,291,34,37),'Altar',version='v2',depth=altar_depth-0.3)
for i,x in enumerate([761,776,791,879,894,909]):
    add('Altar_Candle_%02d'%i,'F%02d'%(25+i),(x-4,277-abs(2.5-i)*6,8,48+abs(2.5-i)*6),'Altar',depth=altar_depth-0.4)

# Seven pew rows on each side; central nave stays open.
for row in range(7):
    bottom=578+row*45
    width=300+row*18
    height=84+row*8
    inner=716-row*9
    add('Pew_Left_%02d'%(row+1),'F%02d'%(row+1),(inner-width,bottom-height,width,height),'Pews',collision=1)
    add('Pew_Right_%02d'%(row+1),'F%02d'%(row+8),(W-inner,bottom-height,width,height),'Pews',collision=1)

# Niches and figures; small depth differences prevent transparent-card z fights.
for side,x,frame,statue in [('Left',604,'A16','F43'),('Right',995,'A17','F44')]:
    d=wall_depth-0.8
    add('Dark_Niche_'+side,frame,(x,182,75,196),'Statues',depth=d)
    add('Rear_Statue_'+side,statue,(x+23,227,30,78),'Statues',depth=d-0.1)
for side,x,frame,statue in [('Left',230,'A18','F45'),('Right',1361,'A19','F46')]:
    d=ground_depth(607)
    add('Stone_Platform_'+side,'F52' if side=='Left' else 'F53',(x-4,511,88,103),'Statues',depth=d,collision=1)
    add('White_Niche_'+side,frame,(x,357,81,171),'Statues',depth=d-0.15)
    add('Middle_Statue_'+side,statue,(x+25,410,31,84),'Statues',depth=d-0.3)
    add('Niche_Garland_'+side,'P03' if side=='Left' else 'P04',(x-5,505,91,42),'Flowers',depth=d-0.45)

# Blue and gold hanging banners.
for name,code,rect,foot in [
    ('Front_Left','F35',(57,224,58,266),780),('Front_Right','F39',(1557,224,58,266),780),
    ('Middle_Left','F36',(225,145,61,205),609),('Middle_Right','F40',(1386,145,61,205),609),
    ('Rear_Left','F37',(350,78,42,165),442),('Rear_Right','F41',(1280,78,42,165),442),
    ('Apse_Left','F38',(492,111,47,139),445),('Apse_Right','F42',(1133,111,47,139),445)]:
    add('Banner_'+name,code,rect,'Banners',depth=ground_depth(foot)-0.4)

# Candlesticks, bouquets and foreground railings.
for name,code,rect in [
    ('Aisle_Left','F15',(571,740,99,194)),('Aisle_Right','F16',(1002,740,99,194)),
    ('Outer_Left','F17',(174,538,71,182)),('Outer_Right','F18',(1427,538,71,182)),
    ('Statue_Left','F19',(328,474,61,142)),('Statue_Right','F20',(1283,474,61,142)),
    ('Platform_Left','F21',(349,277,58,164)),('Platform_Right','F22',(1265,277,58,164)),
    ('Altar_Left','F23',(509,272,56,153)),('Altar_Right','F24',(1107,272,56,153))]:
    add('Candelabrum_'+name,code,rect,'Candles',elevation=2.8 if name.startswith(('Altar','Platform')) else 0,collision=1)
for side,x in [('Left',171),('Right',1461)]:
    add('Wall_Sconce_'+side,'F31' if side=='Left' else 'F32',(x,170,42,70),'Candles',depth=ground_depth(609)-0.5)
for name,code,rect in [
    ('Front_Left','P01',(-55,655,155,249)),('Front_Right','P02',(1572,655,155,249)),
    ('Step_Left','P05',(437,357,82,132)),('Step_Right','P06',(1153,357,82,132)),
    ('Altar_Low_Left','P07',(642,365,91,62)),('Altar_Low_Right','P08',(939,365,91,62)),
    ('Altar_Tall_Left','P09',(680,279,62,114)),('Altar_Tall_Right','P10',(930,279,62,114)),
    ('Window_Left','P11',(611,146,52,36)),('Window_Right','P12',(1009,146,52,36)),
    ('Side_Left','P13',(-25,349,62,97)),('Side_Right','P14',(1635,349,62,97))]:
    d=wall_depth-0.6 if name.startswith('Window') else None
    if name.startswith('Step'):
        d=ground_depth(rect[1]+rect[3])-4.0
    add('Flowers_'+name,code,rect,'Flowers',depth=d,elevation=2.8 if name.startswith('Altar') else 0)
add('Front_Rail_Left','A21',(-95,883,655,198),'Railings',collision=1)
add('Front_Rail_Right','A22',(1112,883,655,198),'Railings',collision=1)
add('Side_Rail_Left','A23',(-180,415,270,123),'Railings',collision=1)
add('Side_Rail_Right','A24',(1582,415,270,123),'Railings',collision=1)

paths=sorted(set(i['path'] for i in items))
ids={p:f'tex_{i}' for i,p in enumerate(paths)}
out=['[gd_scene format=3]', '', '[ext_resource type="PackedScene" path="res://scenes/scene_element.tscn" id="element"]']
for p in paths:
    out.append(f'[ext_resource type="Texture2D" path="res://{p}" id="{ids[p]}"]')
out += ['[ext_resource type="Texture2D" path="res://assets/ground/G01_完整无透视地面贴图-20261025.png" id="ground"]',
    '[ext_resource type="Texture2D" path="res://assets/sky.png" id="sky_texture"]',
    '[ext_resource type="Shader" path="res://shaders/cathedral_floor.gdshader" id="floor_shader"]',
    '[ext_resource type="Shader" path="res://shaders/sunbeam.gdshader" id="beam_shader"]',
    '[ext_resource type="Shader" path="res://shaders/cathedral_finish.gdshader" id="finish_shader"]',
    '[ext_resource type="Shader" path="res://shaders/stained_glass_light.gdshader" id="glass_shader"]',
    '[sub_resource type="PanoramaSkyMaterial" id="sky_mat"]\npanorama = ExtResource("sky_texture")\nenergy_multiplier = 0.4',
    '[sub_resource type="Sky" id="sky"]\nsky_material = SubResource("sky_mat")',
    '[sub_resource type="Environment" id="environment"]\nbackground_mode = 2\nsky = SubResource("sky")\nambient_light_source = 3\nambient_light_color = Color(0.8, 0.72, 0.62, 1)\nambient_light_energy = 0.6\ntonemap_mode = 0',
    '[sub_resource type="ShaderMaterial" id="floor_mat"]\nshader = ExtResource("floor_shader")\nshader_parameter/floor_texture = ExtResource("ground")',
    '[sub_resource type="PlaneMesh" id="floor_mesh"]\nmaterial = SubResource("floor_mat")\nsize = Vector2(48, 64)',
    '[sub_resource type="BoxShape3D" id="floor_collision"]\nsize = Vector3(48, 0.4, 64)',
    '[sub_resource type="PlaneMesh" id="platform_mesh"]\nmaterial = SubResource("floor_mat")\nsize = Vector2(29, 8)',
    '[sub_resource type="BoxShape3D" id="platform_collision"]\nsize = Vector3(29, 2.3, 8)',
    '[sub_resource type="ShaderMaterial" id="finish_mat"]\nshader = ExtResource("finish_shader")',
    '[sub_resource type="ShaderMaterial" id="beam_mat"]\nshader = ExtResource("beam_shader")\nshader_parameter/beam_color = Color(1, 0.86, 0.62, 0.26)',
    '[sub_resource type="QuadMesh" id="beam_mesh"]\nmaterial = SubResource("beam_mat")\nsize = Vector2(1, 1)',
    f'[sub_resource type="ShaderMaterial" id="glass_mat"]\nshader = ExtResource("glass_shader")\nshader_parameter/glass_texture = ExtResource("{ids[asset("A11")]}")',
    '[sub_resource type="PlaneMesh" id="glass_mesh"]\nmaterial = SubResource("glass_mat")\nsize = Vector2(3.5, 7)',
    '[node name="Cathedral" type="Node3D"]',
    '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("environment")',
    '[node name="Sun" type="DirectionalLight3D" parent="."]\nrotation_degrees = Vector3(-48, -25, 0)\nlight_color = Color(1, 0.83, 0.58, 1)\nlight_energy = 0.5',
    '[node name="Ground" type="StaticBody3D" parent="."]\nposition = Vector3(0, 0, -10)',
    '[node name="Surface" type="MeshInstance3D" parent="Ground"]\nmesh = SubResource("floor_mesh")',
    '[node name="CollisionShape3D" type="CollisionShape3D" parent="Ground"]\nposition = Vector3(0, -0.2, 0)\nshape = SubResource("floor_collision")',
    '[node name="SanctuaryPlatform" type="StaticBody3D" parent="."]\nposition = Vector3(0, 2.3, -4.2)',
    '[node name="Surface" type="MeshInstance3D" parent="SanctuaryPlatform"]\nmesh = SubResource("platform_mesh")',
    '[node name="CollisionShape3D" type="CollisionShape3D" parent="SanctuaryPlatform"]\nposition = Vector3(0, -1.15, 0)\nshape = SubResource("platform_collision")',
    '[node name="Elements" type="Node3D" parent="."]']
for group in dict.fromkeys(i['group'] for i in items):
    out.append(f'[node name="{group}" type="Node3D" parent="Elements"]')
    for i in (i for i in items if i['group']==group):
        shade = {'Architecture': '0.70, 0.63, 0.55, 1', 'Columns': '0.88, 0.80, 0.68, 1', 'Pews': '0.84, 0.73, 0.61, 1'}.get(group, '1, 0.97, 0.9, 1')
        out.append(f'''[node name="{i['name']}" parent="Elements/{group}" instance=ExtResource("element")]
position = Vector3({vec(i['pos'])})
rotation_degrees = Vector3(-28, 0, 0)
texture = ExtResource("{ids[i['path']]}")
pixel_size = {i['pixel']:.9f}
size_scale = Vector2(1, {i['scale_y']:.7f})
flip_h = {str(i['flip']).lower()}
collision_mode = {i['collision']}
collision_depth = 0.35
receive_lighting = false
tint = Color({shade})
metadata/reference_rect = Rect2({', '.join(str(n) for n in i['rect'])})''')

out.append('[node name="Atmosphere" type="Node3D" parent="."]')
for n,(x,y) in enumerate([(790,570),(875,725),(825,885),(1220,700),(440,565)]):
    p=position(x,y,ground_depth(y)); p=(p[0],0.035,p[2])
    out.append(f'[node name="WindowLightPool{n}" type="MeshInstance3D" parent="Atmosphere"]\nposition = Vector3({vec(p)})\nrotation_degrees = Vector3(0, -24, 0)\ncast_shadow = 0\nmesh = SubResource("glass_mesh")')
# Screen-space composition, but genuine transparent 3D light cards.
for n,(start,end,width) in enumerate([((646,-50),(510,510),80),((831,-55),(709,588),105),((1040,-45),(1173,566),110),((1083,12),(1430,655),52)]):
    d=18.0; u=2*d*T/H
    mid=((start[0]+end[0])/2,(start[1]+end[1])/2)
    length=math.dist(start,end)
    angle=-math.degrees(math.atan2(end[0]-start[0],end[1]-start[1]))
    out.append(f'[node name="BeamPivot{n}" type="Node3D" parent="Atmosphere"]\nposition = Vector3({vec(position(*mid,d))})\nrotation_degrees = Vector3(-28, 0, 0)')
    out.append(f'[node name="Sunbeam" type="MeshInstance3D" parent="Atmosphere/BeamPivot{n}"]\nrotation_degrees = Vector3(0, 0, {angle:.6f})\nscale = Vector3({width*u:.6f}, {length*u:.6f}, 1)\ncast_shadow = 0\nmesh = SubResource("beam_mesh")')
out.append('[node name="Camera3D" type="Camera3D" parent="."]\nposition = Vector3(0, 18, 32)\nrotation_degrees = Vector3(-28, 0, 0)\ncurrent = true\nfov = 45.0\nnear = 0.1\nfar = 200.0')
out.append('[node name="ColorFinish" type="CanvasLayer" parent="."]\nlayer = 2')
out.append('[node name="SoftGlowAndVignette" type="ColorRect" parent="ColorFinish"]\nmaterial = SubResource("finish_mat")\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\nmouse_filter = 2')
(ROOT/'scenes/cathedral.tscn').write_text('\n\n'.join(out)+'\n',encoding='utf-8')
(ROOT/'docs/cathedral_layout.json').write_text(json.dumps(items,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'Built cathedral: {len(items)} editable elements, {len(paths)} textures.')
