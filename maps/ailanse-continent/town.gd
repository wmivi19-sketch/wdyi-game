extends Node3D

var camera: Camera3D
var player: CharacterBody3D
var nav: NavigationRegion3D
var materials := {}
var footprints: Array = []
var elapsed := 0.0
var captured := false
var status_label: Label
var info_panel: PanelContainer
var info_label: Label
var interaction_areas: Array[Area3D] = []
var walkers: Array[CharacterBody3D] = []
var follow_player := false
var photo_mode := false
var ui_layer: CanvasLayer
var info_open := false
var interaction_count := 0
var district_type := "wine"

func mat(key: String, color: Color, brick := false, glow := false) -> Material:
	if materials.has(key): return materials[key]
	if brick:
		var masonry := ShaderMaterial.new()
		masonry.shader = load("res://masonry.gdshader")
		masonry.set_shader_parameter("base_color",color)
		masonry.set_shader_parameter("slate",key=="roof")
		materials[key]=masonry
		return masonry
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.35
	materials[key] = m
	return m

func surface_material(paving: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader=load("res://concrete.gdshader")
	m.set_shader_parameter("paving",paving)
	m.set_shader_parameter("base_color",Color("706b5e") if paving else Color("626867"))
	return m
func box(p: Vector3, size: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = p
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = size
		collision.shape = s
		body.add_child(collision)
		mesh.add_child(body)
	return mesh

func cylinder(p: Vector3, radius: float, height: float, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 10
	mesh.mesh = c
	mesh.material_override = material
	mesh.position = p
	add_child(mesh)

func building(id: String, x: float, z: float, w: float, d: float, h: float, stone := false) -> void:
	var wall := mat("stone" if stone else "brick", Color("b8aa8d") if stone else Color("974f35"),true)
	var trim := mat("trim",Color("a99a80"))
	var roof := mat("roof",Color("293641"),true)
	box(Vector3(x,h/2,z),Vector3(w,h,d),wall,true)
	footprints.append({"id":id,"x":x,"z":z,"width":w,"depth":d,"height":h})
	for y in [0.25,3.2,h-0.25]:
		box(Vector3(x,y,z),Vector3(w+0.3,0.22,d+0.3),trim)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(x-w/2-0.4,h,z-d/2-0.4)
	var b := Vector3(x+w/2+0.4,h,z-d/2-0.4)
	var c := Vector3(x+w/2+0.4,h,z+d/2+0.4)
	var e := Vector3(x-w/2-0.4,h,z+d/2+0.4)
	var u := Vector3(x-w/2-0.4,h+3,z)
	var v := Vector3(x+w/2+0.4,h+3,z)
	for point in [a,u,v,a,v,b,e,c,v,e,v,u,a,e,u,b,v,c]: st.add_vertex(point)
	st.generate_normals()
	var r := MeshInstance3D.new()
	r.mesh = st.commit()
	r.material_override = roof

	add_child(r)
	for cx in [x-w*0.3,x+w*0.3]:
		box(Vector3(cx,h+2.5,z-1),Vector3(0.9,4,0.9),wall)
		box(Vector3(cx,h+4.5,z-1),Vector3(1.2,0.3,1.2),trim)
	var glass := mat("glass",Color("ffb84d"),false,true)
	var dark := mat("dark",Color("25312c"))
	for wx in range(int(w/2.8)):
		for wy in range(int(h/3)):
			var p := Vector3(x-w/2+1.5+wx*2.8,1.8+wy*3,z+d/2+0.04)
			box(p,Vector3(1.2,1.75,0.12),trim)
			box(p+Vector3(0,0,0.08),Vector3(0.9,1.45,0.08),glass)
			box(p+Vector3(0,0,0.14),Vector3(0.08,1.45,0.08),dark)
			box(p+Vector3(0,0,0.14),Vector3(0.9,0.08,0.08),dark)
	for wz in range(int(d/3)):
		for wy in range(int(h/3)):
			box(Vector3(x+w/2+0.06,1.8+wy*3,z-d/2+1.5+wz*3),Vector3(0.12,1.4,0.85),glass)
	box(Vector3(x,1.3,z+d/2+0.2),Vector3(1.5,2.6,0.25),dark)
	box(Vector3(x,2.9,z+d/2+0.5),Vector3(2.7,0.25,1.1),trim)

func lamp(x: float,z: float, lit: bool) -> void:
	var iron := mat("iron",Color("222d2a"))
	cylinder(Vector3(x,0.2,z),0.3,0.4,iron)
	cylinder(Vector3(x,2.3,z),0.09,4.3,iron)
	cylinder(Vector3(x,4.2,z),0.27,0.14,iron)
	box(Vector3(x,4.55,z),Vector3(0.45,0.65,0.45),mat("lantern",Color("ffd075"),false,true))
	box(Vector3(x,4.93,z),Vector3(0.65,0.12,0.65),iron)
	for dx in [-0.22,0.22]:
		for dz in [-0.22,0.22]: box(Vector3(x+dx,4.55,z+dz),Vector3(0.035,0.7,0.035),iron)
	for y in [0.5,0.65,3.6]: cylinder(Vector3(x,y,z),0.16,0.09,iron)
	add_round_collision(Vector3(x,2,z),0.2,4)
	var halo:=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2(2.8,2.8)
	halo.mesh=quad
	halo.position=Vector3(x,4.6,z)
	halo.rotation_degrees=Vector3(-38,35,0)
	var hm:=ShaderMaterial.new()
	hm.shader=load("res://halo.gdshader")
	halo.material_override=hm
	halo.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	if lit:
		var l := OmniLight3D.new()
		l.position = Vector3(x,4.4,z)
		l.light_color = Color("ffc06a")
		l.light_energy = 1.0
		l.omni_range = 11
		add_child(l)

func barrel(p: Vector3) -> void:
	cylinder(p+Vector3(0,0.6,0),0.43,1.2,mat("wood",Color("8e6436")))
	for h in [0.18,0.95]: cylinder(p+Vector3(0,h,0),0.45,0.08,mat("iron",Color("222d2a")))
	add_round_collision(p+Vector3(0,0.6,0),0.45,1.2)

func cargo(p: Vector3) -> void:
	if district_type=="wine":
		barrel(p)
	elif district_type=="wheat":
		var sack:=MeshInstance3D.new()
		var mesh:=SphereMesh.new()
		mesh.radius=0.43
		mesh.height=1.05
		mesh.radial_segments=10
		mesh.rings=6
		sack.mesh=mesh
		sack.material_override=mat("sack",Color("a78e5f"))
		sack.position=p+Vector3(0,0.52,0)
		add_child(sack)
		cylinder(p+Vector3(0,1,0),0.19,0.12,mat("twine",Color("55432c")))
		add_round_collision(p+Vector3(0,0.52,0),0.43,1.05)
	else:
		box(p+Vector3(0,0.5,0),Vector3(0.85,1,0.8),mat("linen",Color("c6bca0")),true)
		for x in [-0.23,0.23]: box(p+Vector3(x,0.5,0.41),Vector3(0.04,1.02,0.04),mat("twine",Color("55432c")))

func add_round_collision(p: Vector3,r: float,h: float) -> void:
	var body:=StaticBody3D.new()
	var c:=CollisionShape3D.new()
	var shape:=CylinderShape3D.new()
	shape.radius=r
	shape.height=h
	c.shape=shape
	body.position=p
	body.add_child(c)
	add_child(body)

func sprite_person(p: Vector3, color: Color) -> Sprite3D:
	var img:=Image.create(96,40,false,Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for frame in range(4):
		var ox:=frame*24
		var step:=2 if frame==1 else (-2 if frame==3 else 0)
		img.fill_rect(Rect2i(ox+8,27+step,4,11-step),Color("26292c"))
		img.fill_rect(Rect2i(ox+14,27-step,4,11+step),Color("313439"))
		img.fill_rect(Rect2i(ox+6,37+mini(step,0),6,2),Color("1c2325"))
		img.fill_rect(Rect2i(ox+14,37-maxi(step,0),6,2),Color("1c2325"))
		img.fill_rect(Rect2i(ox+6,14,14,17),color.darkened(0.22))
		img.fill_rect(Rect2i(ox+8,14,9,16),color)
		img.fill_rect(Rect2i(ox+11,14,4,7),Color("cfbc8c"))
		img.fill_rect(Rect2i(ox+12,14,2,5),Color("513a2d"))
		img.fill_rect(Rect2i(ox+13,22,1,7),color.lightened(0.22))
		img.fill_rect(Rect2i(ox+3,16+step,3,11),color.darkened(0.15))
		img.fill_rect(Rect2i(ox+20,16-step,3,11),color.darkened(0.25))
		img.fill_rect(Rect2i(ox+3,27+step,3,3),Color("c49b74"))
		img.fill_rect(Rect2i(ox+20,27-step,3,3),Color("c49b74"))
		img.fill_rect(Rect2i(ox+9,6,9,8),Color("cba37c"))
		img.fill_rect(Rect2i(ox+9,6,2,7),Color("77543d"))
		img.fill_rect(Rect2i(ox+16,9,2,1),Color("2a2825"))
		img.fill_rect(Rect2i(ox+8,1,10,6),Color("243138"))
		img.fill_rect(Rect2i(ox+8,5,10,2),Color("716347"))
		img.fill_rect(Rect2i(ox+5,7,16,2),Color("202c30"))
	var s:=Sprite3D.new()
	s.name="Portrait"
	s.texture=ImageTexture.create_from_image(img)
	s.hframes=4
	s.pixel_size=0.05
	s.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.position=p
	return s

func animate_person(body: CharacterBody3D) -> void:
	var sprite: Sprite3D=body.get_node_or_null("Portrait")
	if sprite==null: return
	var speed:=Vector2(body.velocity.x,body.velocity.z).length()
	sprite.frame=int(elapsed*8.0)%4 if speed>0.2 else 0
	if absf(body.velocity.x)>0.05: sprite.flip_h=body.velocity.x<0
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--district="): district_type=arg.get_slice("=",1)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8e9b98")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b4c3cc")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled=true
	env.fog_mode=Environment.FOG_MODE_DEPTH
	env.fog_depth_begin=165
	env.fog_depth_end=370
	env.fog_light_color=Color("a3a494")
	env.fog_light_energy=0.5
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		env.ssao_enabled=true
		env.ssao_radius=1.8
		env.ssao_intensity=1.4
		env.ssao_light_affect=0.55
		env.glow_enabled=true
		env.glow_intensity=0.5
		env.glow_hdr_threshold=1.25
		env.ssr_enabled=true
		env.ssr_max_steps=64
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-30,0)
	sun.light_color = Color("ffdaad")
	sun.light_energy = 0.48
	sun.shadow_enabled = true
	add_child(sun)
	box(Vector3(0,-0.5,0),Vector3(160,1,120),mat("ground",Color("414832")),true)
	var road := surface_material(false)
	box(Vector3(0,0.02,0),Vector3(160,0.04,8),road)
	box(Vector3(14,0.025,0),Vector3(4,0.05,120),road)
	var pavement := surface_material(true)
	for z in [-5.0,5.0]: box(Vector3(0,0.08,z),Vector3(160,0.16,2),pavement)
	for x in [11.0,17.0]: box(Vector3(x,0.08,0),Vector3(2,0.16,120),pavement)
	box(Vector3(-20,0.02,-20),Vector3(42,0.04,27),pavement)
	building("winery",-24,-33,20,13,9)
	building("export_warehouse",33,-24,22,15,6,true)
	building("wine_merchant",-12,19,12,12,9)
	for x in [-42,-30,30,43,56]: building("row_%s"%x,x,20,10,11,6)
	for x in [-65,-53]: building("worker_%s"%x,x,-18,9,9,6)
	for spec in [[-13,-51,6],[1,-37,6],[30,-48,9],[48,-48,6],[61,-25,6],[-34,41,6],[-17,43,9],[39,43,6]]:
		building("secondary_%s_%s"%[spec[0],spec[1]],spec[0],spec[1],11,10,spec[2])
	for x in range(-70,76,14):
		if abs(x-14)<3: continue
		lamp(x,-5.2,abs(x)<42)
		lamp(x,5.2,abs(x)<42)
	for z in [-44,-30,-16,16,30,44]: lamp(17.2,z,abs(z)<31)
	for i in range(25): cargo(Vector3(-37+(i%9)*1.2,0.1,-23+int(i/9)*1.5))
	for i in range(12): cargo(Vector3(25+(i%6)*1.2,0.1,-13+int(i/6)*1.5))
	# Low brick garden walls and iron railings articulate the street edges.
	for extent in [[-45.0,-4.0,-8.0],[22.0,47.0,-10.0],[-48.0,1.0,9.0],[25.0,62.0,9.0]]:
		var lo: float = extent[0]
		var hi: float = extent[1]
		var z: float = extent[2]
		for x in range(int(lo),int(hi)):
			if absf(x-(-24 if lo<0 else 33))<2.5: continue
			box(Vector3(x,0.32,z),Vector3(0.95,0.64,0.45),mat("brick",Color("974f35"),true),true)
			box(Vector3(x,1.0,z),Vector3(0.06,0.9,0.06),mat("iron",Color("222d2a")))
			box(Vector3(x,1.3,z),Vector3(1,0.06,0.06),mat("iron",Color("222d2a")))
	for i in range(12): add_child(sprite_person(Vector3(-45+i*8,1.1,4.8),Color("354647") if i%2 else Color("663936")))
	var details=load("res://details.gd").new(self)
	details.build()
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0,1.2,0)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	collider.shape = capsule
	player.add_child(collider)
	player.add_child(sprite_person(Vector3.ZERO,Color("386a94")))
	add_child(player)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 76
	camera.position = Vector3(78,100,107)
	add_child(camera)
	camera.look_at(Vector3(-7,0,-14))
	camera.current = true
	build_navigation()
	build_interactions()
	spawn_walkers()
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var ui:=ui_layer
	var font:=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC"])
	var label := Label.new()
	label.text = "艾兰瑟  /  葡萄酒镇\nWASD 行走 · F 跟随 · 方向键移镜 · 滚轮缩放 · Home 总览 · P 隐藏界面"
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",17)
	label.position = Vector2(20,16)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	ui.add_child(label)
	status_label=Label.new()
	status_label.position=Vector2(20,750)
	status_label.add_theme_font_override("font",font)
	status_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	status_label.add_theme_constant_override("shadow_offset_x",2)
	status_label.add_theme_constant_override("shadow_offset_y",2)
	ui.add_child(status_label)
	info_panel=PanelContainer.new()
	info_panel.position=Vector2(24,110)
	info_panel.custom_minimum_size=Vector2(390,160)
	var panel_style:=StyleBoxFlat.new()
	panel_style.bg_color=Color(0.07,0.10,0.09,0.94)
	panel_style.content_margin_left=22
	panel_style.content_margin_right=22
	panel_style.content_margin_top=18
	panel_style.content_margin_bottom=18
	panel_style.border_color=Color("b39a60")
	panel_style.set_border_width_all(1)
	info_panel.add_theme_stylebox_override("panel",panel_style)
	info_label=Label.new()
	info_label.add_theme_font_override("font",font)
	info_label.add_theme_font_size_override("font_size",18)
	info_panel.add_child(info_label)
	ui.add_child(info_panel)
	info_panel.hide()
	if "--verify" in OS.get_cmdline_user_args(): FileAccess.open("res://layout.json",FileAccess.WRITE).store_string(JSON.stringify({"version":1,"units":"metres","world_extent":[1000,1000],"sample_extent":[160,120],"transform":"X=E-500,Y=height,Z=500-N","buildings":footprints},"\t"))

func build_navigation() -> void:
	nav = NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	var vertices := PackedVector3Array()
	# Shared vertices make the road-grid cells connected. 0.6m inset clears lamps/curbs.
	var xs := [-79.0,12.6,15.4,79.0]
	var zs := [-59.0,-3.4,3.4,59.0]
	for z in zs:
		for x in xs: vertices.append(Vector3(x,0.05,z))
	mesh.vertices = vertices
	for zi in range(3):
		for xi in range(3):
			if zi==1 or xi==1:
				var n := zi*4+xi
				mesh.add_polygon(PackedInt32Array([n,n+4,n+5,n+1]))
	nav.navigation_mesh = mesh
	add_child(nav)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: camera.size=maxf(25,camera.size-5)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: camera.size=minf(160,camera.size+5)
	if event is InputEventKey and event.pressed and event.keycode==KEY_HOME:
		follow_player=false
		camera.position=Vector3(78,100,107)
		camera.look_at(Vector3(-7,0,-14))
		camera.size=76
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F: follow_player=not follow_player
		if event.keycode==KEY_P:
			photo_mode=not photo_mode
			ui_layer.visible=not photo_mode
		if event.keycode==KEY_E:
			if info_open:
				info_panel.hide()
				info_open=false
			else:
				var area:=nearby_interaction()
				if area!=null: show_interaction(area)
		if event.keycode==KEY_ESCAPE:
			info_panel.hide()
			info_open=false

func _physics_process(delta: float) -> void:
	var move := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	player.velocity.x=move.normalized().x*5
	player.velocity.z=move.normalized().z*5
	player.velocity.y-=20*delta
	player.move_and_slide()
	player.position.x=clampf(player.position.x,-79,79)
	player.position.z=clampf(player.position.z,-59,59)
	var pan := Vector3(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),0,float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
	camera.position+=pan*30*delta
	if pan.length()>0: follow_player=false
	if follow_player:
		camera.position=camera.position.lerp(player.position+Vector3(40,48,56),delta*4)
		camera.look_at(camera.position-Vector3(40,48,56))
		camera.size=lerpf(camera.size,32,delta*3)
	update_walkers(delta)
	var nearby:=nearby_interaction()
	status_label.text="E 查看："+str(nearby.get_meta("title")) if nearby!=null else "蓝衣旅人 · 沿街探索酒庄、出口仓库与酒商店铺"
	elapsed+=delta
	if elapsed>2 and not captured and "--verify" in OS.get_cmdline_user_args():
		captured=true
		verify()

func build_interactions() -> void:
	var points: Array = [
		["winery",Vector3(-24,1,-5),"艾兰瑟酒庄","葡萄采收 → 压榨 → 发酵 → 橡木桶陈酿\n\n山麓与黄石滩附近的葡萄进入这座酒庄。\n货场连接沿街运输道路。\n\nE / Esc 关闭"],
		["depot",Vector3(33,1,-6),"葡萄酒出口仓库","陈酿装桶 → 装车集散 → 供应全艾兰瑟大陆\n\n雨棚下暂存桶装葡萄酒，货车在院内装卸。\n目前为产业展示，尚无交易系统。\n\nE / Esc 关闭"],
		["merchant",Vector3(-12,1,6),"酒商与商店街","统一的砖石建筑语言，繁荣的葡萄酒商贸。\n\n暖色橱窗、绿色木饰与铸铁阳台\n标识酒商店铺，住宅沿两侧展开。\n\nE / Esc 关闭"]]
	for entry in points:
		var area:=Area3D.new()
		area.name="Interact_"+str(entry[0])
		area.position=entry[1]
		area.collision_layer=0
		area.collision_mask=1
		area.set_meta("title",entry[2])
		area.set_meta("description",entry[3])
		var collider:=CollisionShape3D.new()
		var sphere:=SphereShape3D.new()
		sphere.radius=2.6
		collider.shape=sphere
		area.add_child(collider)
		add_child(area)
		interaction_areas.append(area)

func nearby_interaction() -> Area3D:
	for area in interaction_areas:
		if area.overlaps_body(player): return area
	return null

func show_interaction(area: Area3D) -> void:
	info_label.text=str(area.get_meta("title"))+"\n\n"+str(area.get_meta("description"))
	info_panel.show()
	info_open=true
	interaction_count+=1

func spawn_walkers() -> void:
	for i in range(4):
		var body:=CharacterBody3D.new()
		body.name="Pedestrian_%d"%i
		body.position=Vector3(-46+i*25,1.1,1.8 if i%2 else -1.8)
		# Walkers collide with scenery, not the player or one another.
		body.collision_layer=2
		body.collision_mask=1
		var collision:=CollisionShape3D.new()
		var shape:=CapsuleShape3D.new()
		shape.height=1.8
		shape.radius=0.28
		collision.shape=shape
		body.add_child(collision)
		body.add_child(sprite_person(Vector3.ZERO,Color("604f47") if i%2 else Color("354c42")))
		var agent:=NavigationAgent3D.new()
		agent.name="Agent"
		agent.path_height_offset=-0.85
		agent.path_desired_distance=0.4
		agent.target_desired_distance=0.65
		body.add_child(agent)
		body.set_meta("going_east",i%2==0)
		body.set_meta("start_position",body.position)
		add_child(body)
		walkers.append(body)

func update_walkers(delta: float) -> void:
	if elapsed<0.3: return
	for body in walkers:
		var agent: NavigationAgent3D=body.get_node("Agent")
		if agent.is_navigation_finished() or not body.has_meta("started"):
			var east: bool=not bool(body.get_meta("going_east"))
			body.set_meta("going_east",east)
			body.set_meta("started",true)
			agent.target_position=Vector3(65 if east else -65,0.05,body.position.z)
		var next:=agent.get_next_path_position()
		var direction:=next-body.position
		direction.y=0
		direction=direction.normalized()
		body.velocity.x=direction.x*1.4
		body.velocity.z=direction.z*1.4
		body.velocity.y-=20*delta
		body.move_and_slide()

func verify() -> void:
	var space := get_world_3d().direct_space_state
	var checks := {}
	for p in [Vector3(-70,10,-50),Vector3(70,10,50),Vector3(0,10,0),Vector3(14,10,-50)]:
		var result := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p-Vector3(0,30,0)))
		checks[str(p)] = not result.is_empty()
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-24,2,-10),Vector3(-24,2,-40)))
	var route := NavigationServer3D.map_get_path(nav.get_navigation_map(),Vector3(-65,0.05,0),Vector3(14,0.05,-50),true)
	var probe:=Transform3D(Basis.IDENTITY,Vector3(-24,1.1,-24))
	var blocks_building:=player.test_move(probe,Vector3(0,0,-5))
	var clear_gate:=not player.test_move(Transform3D(Basis.IDENTITY,Vector3(-24,1.1,-5)),Vector3(0,0,-7))
	var path_clear:=true
	for i in range(route.size()-1):
		var a: Vector3=route[i]+Vector3(0,1.05,0)
		var b: Vector3=route[i+1]+Vector3(0,1.05,0)
		if player.test_move(Transform3D(Basis.IDENTITY,a),b-a): path_clear=false
	var walkers_moving:=walkers.size()==4
	for body in walkers:
		if body.position.distance_to(body.get_meta("start_position"))<0.5: walkers_moving=false
	var saved_position:=player.position
	player.position=interaction_areas[0].position
	player.velocity=Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	var trigger_ok:=interaction_areas[0].overlaps_body(player)
	show_interaction(interaction_areas[0])
	var panel_ok:=info_panel.visible and info_label.text.contains("艾兰瑟酒庄")
	info_panel.hide()
	info_open=false
	player.position=saved_position
	var report := {"ground_probes":checks,"winery_collision":not wall.is_empty(),"capsule_blocked_by_winery":blocks_building,"winery_gate_clear":clear_gate,"navigation_path_points":route.size(),"navigation_capsule_sweep_clear":path_clear,"walkers_moving":walkers_moving,"interaction_trigger":trigger_ok,"interaction_panel":panel_ok,"player_grounded":player.is_on_floor(),"building_count":footprints.size(),"engine":Engine.get_version_info().string}
	report["renderer"]=RenderingServer.get_current_rendering_method()
	report["editable_scene_saved"]=save_editor_scene()
	var logical_points: Array=[]
	for area in interaction_areas:
		logical_points.append({"id":str(area.name),"position":[area.position.x,area.position.y,area.position.z],"radius":2.6,"title":area.get_meta("title")})
	var nav_vertices: Array=[]
	for point in nav.navigation_mesh.vertices: nav_vertices.append([point.x,point.y,point.z])
	var polygons: Array=[]
	for i in range(nav.navigation_mesh.get_polygon_count()): polygons.append(Array(nav.navigation_mesh.get_polygon(i)))
	FileAccess.open("res://logic.json",FileAccess.WRITE).store_string(JSON.stringify({"version":2,"unit":"metre","transform":"X=E-500,Y=height,Z=500-N","ground_y":0,"terrain_height_source":"designed_flat_plane","sample_bounds":{"x":[-80,80],"z":[-60,60]},"buildings":footprints,"roads":[{"id":"main","width":8,"centerline":[[-80,0],[80,0]]},{"id":"lane","width":4,"centerline":[[14,-60],[14,60]]}],"navigation":{"vertices":nav_vertices,"polygons":polygons,"tested_character_radius":0.35,"tested_character_height":1.8,"scope":"road interiors only"},"interactions":logical_points},"\t"))
	var all_passed:=true
	for key in ["winery_collision","capsule_blocked_by_winery","winery_gate_clear","navigation_capsule_sweep_clear","walkers_moving","interaction_trigger","interaction_panel","player_grounded","editable_scene_saved"]:
		if not report[key]: all_passed=false
	for value in checks.values():
		if not value: all_passed=false
	all_passed=all_passed and route.size()>1
	report["all_passed"]=all_passed
	FileAccess.open("res://verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	if DisplayServer.get_name()!="headless":
		ui_layer.hide()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://engine_preview.png")
		camera.position=Vector3(-19,0,-25)+Vector3(48,58,69)
		camera.look_at(Vector3(-19,0,-25))
		camera.size=49
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://engine_detail.png")
		ui_layer.show()
		show_interaction(interaction_areas[0])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://engine_interaction.png")
	get_tree().quit(0 if all_passed else 1)

func set_preview_owners(node: Node,root: Node) -> void:
	for child in node.get_children():
		child.owner=root
		set_preview_owners(child,root)

func save_editor_scene() -> bool:
	var snapshot:=Node3D.new()
	snapshot.name="WineTown_Editable"
	for child in get_children():
		if child==ui_layer or child is CharacterBody3D or child is Area3D: continue
		snapshot.add_child(child.duplicate())
	set_preview_owners(snapshot,snapshot)
	var packed:=PackedScene.new()
	var result:=packed.pack(snapshot)
	if result==OK: result=ResourceSaver.save(packed,"res://town_editable.tscn" if district_type=="wine" else "res://town_%s.tscn"%district_type)
	snapshot.free()
	return result==OK
