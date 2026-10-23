extends "res://town.gd"

var regions: Array=[]
var visited: Array[String]=[]
var active_index:=0
var active_chunk: Node3D
var region_map: Control
var region_label: Label
var world_time:=0.0
var checking:=false
var travel_busy:=false
var lod_towns: Array[Node3D]=[]
var world_results: Dictionary={}
var landscape: RefCounted
var street: RefCounted
var roofs: RefCounted
var farfield: RefCounted
var vineyard: RefCounted
var houses: RefCounted
var roads: RefCounted

func center(index: int) -> Vector3:
	var values: Array=regions[index].center
	return Vector3(values[0],0,values[1])

func _ready() -> void:
	regions=JSON.parse_string(FileAccess.get_file_as_string("res://regions.json")).regions
	super._ready()
	for node in get_children():
		if node is WorldEnvironment:
			node.environment.fog_depth_begin=450
			node.environment.fog_depth_end=1600
	active_chunk=Node3D.new()
	active_chunk.name="ActiveTown"
	var prior:=get_children()
	add_child(active_chunk)
	for node in prior:
		if node is WorldEnvironment or node is DirectionalLight3D or node==player or node==camera or node==nav or node==ui_layer or node is Area3D or node is CharacterBody3D: continue
		node.reparent(active_chunk)
	active_chunk.position=center(0)
	# Replace the local navigation with a single connected world road network.
	nav.free()
	build_world_navigation()
	landscape=load("res://landscape_v4.gd").new(self)
	street=load("res://street_v5.gd").new(self)
	roofs=load("res://roof_v6.gd").new(self)
	farfield=load("res://farfield_v7.gd").new(self)
	vineyard=load("res://vineyard_v8.gd").new()
	houses=load("res://houses_v9.gd").new(self)
	roads=load("res://roads_v10.gd").new(self)
	build_landscape()
	landscape.build()
	landscape.decorate_town(active_chunk)
	street.decorate(active_chunk,regions[0].theme)
	roofs.decorate(active_chunk)
	vineyard.decorate(active_chunk,regions[0].theme)
	houses.decorate(active_chunk)
	roads.decorate(active_chunk)
	build_region_map()
	for i in range(4): make_distant_town(i)
	region_label=ui_layer.get_child(0)
	place_actors(0)
	if "--world-verify" in OS.get_cmdline_user_args(): checking=true

func build_landscape() -> void:
	box(Vector3(0,-0.5,0),Vector3(1000,1,1000),landscape.ground,true)
	var road:=surface_material(false)
	for z in [-250,250]: box(Vector3(-45,0.015,z),Vector3(870,0.03,8),road)
	for x in [-236,264]: box(Vector3(x,0.017,45),Vector3(4,0.034,870),road)
	# Fictional shore/mountain design, not extracted heights or geographic data.
	box(Vector3(460,0.02,0),Vector3(80,0.04,1000),water_material())
	box(Vector3(416,0.01,0),Vector3(8,0.04,1000),mat("yellow_shore",Color("b6a47a")))
	var barrier:=box(Vector3(460,2,0),Vector3(80,4,1000),mat("water_barrier",Color("4d7882")),true)
	barrier.visible=false
	var rng:=RandomNumberGenerator.new()
	rng.seed=411
	farfield.build_mountains()
	for i in range(25):
		var rock:=MeshInstance3D.new()
		var mesh:=SphereMesh.new()
		mesh.radius=rng.randf_range(1.2,4)
		mesh.height=mesh.radius*1.4
		mesh.radial_segments=6
		mesh.rings=4
		rock.mesh=mesh
		rock.material_override=mat("coast_rock",Color("a39375"))
		rock.position=Vector3(rng.randf_range(414,425),mesh.height*0.3,-470+i*38)
		add_child(rock)
	for z in [-250,250]:
		for x in range(-460,390,35):
			if abs(x+250)<85 or abs(x-250)<85: continue
			lamp(x,z-5.2,true)
	for x in [-236,264]:
		for z in range(-380,480,35):
			if abs(z+250)<65 or abs(z-250)<65: continue
			lamp(x+3.2,z,true)
	# A loading pier beside the wine port. Water is blocked; no swimming.
	box(Vector3(398,0.05,-250),Vector3(38,0.1,6),mat("pier",Color("776044")))
	for x in [385,395,405,415]:
		for z in [-253.2,-246.8]: cylinder(Vector3(x,0.8,z),0.18,1.6,mat("pier_poles",Color("514331")))

func make_distant_town(index: int) -> void:
	lod_towns.append(farfield.make_town(index))

func build_world_navigation() -> void:
	nav=NavigationRegion3D.new()
	var mesh:=NavigationMesh.new()
	var xs: Array[float]=[-479,-237.4,-234.6,262.6,265.4,389]
	var zs: Array[float]=[-389,-253.4,-246.6,246.6,253.4,479]
	var vertices:=PackedVector3Array()
	for z in zs:
		for x in xs: vertices.append(Vector3(x,0.05,z))
	mesh.vertices=vertices
	for z in range(5):
		for x in range(5):
			if x in [1,3] or z in [1,3]:
				var i:=z*6+x
				mesh.add_polygon(PackedInt32Array([i,i+6,i+7,i+1]))
	nav.navigation_mesh=mesh
	add_child(nav)

func build_region_map() -> void:
	region_map=Control.new()
	region_map.set_script(load("res://regional_map.gd"))
	region_map.world=self
	region_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(region_map)
	var font:=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei"])
	for i in range(4):
		var btn:=Button.new()
		btn.position=Vector2(705,120+i*139)
		btn.size=Vector2(530,108)
		btn.text="%d  %s\n%s\n前往此镇"%[i+1,regions[i].name,regions[i].industry]
		btn.add_theme_font_override("font",font)
		btn.add_theme_font_size_override("font_size",19)
		var panel:=StyleBoxFlat.new()
		panel.bg_color=Color("293b31")
		panel.border_color=Color("a39061")
		panel.set_border_width_all(1)
		btn.add_theme_stylebox_override("normal",panel)
		btn.pressed.connect(func(): travel_to(i))
		region_map.add_child(btn)
	region_map.hide()

func place_actors(index: int, teleport:=true) -> void:
	active_index=index
	var c:=center(index)
	if teleport: player.position=c+Vector3(0,1.2,0)
	player.velocity=Vector3.ZERO
	if teleport:
		camera.position=c+Vector3(78,100,107)
		camera.look_at(c+Vector3(-7,0,-14))
		camera.size=76
		follow_player=false
	for i in range(walkers.size()):
		var body:=walkers[i]
		body.position=c+Vector3(-46+i*25,1.1,1.8 if i%2 else -1.8)
		body.velocity=Vector3.ZERO
		body.remove_meta("started")
	var positions: Array[Vector3]=[Vector3(-24,1,-5),Vector3(33,1,-6),Vector3(-12,1,6)]
	var titles: Array=["酒庄与陈酿","葡萄酒集散仓库","酒商店铺"]
	var descriptions: Array=["葡萄采收 → 压榨 → 发酵 → 陈酿","装桶 → 仓储 → 外运，供应全艾兰瑟大陆","沿街店铺经营本地葡萄酒与商贸"]
	if regions[index].theme=="wheat":
		titles=["麦作磨坊","粮食仓库","面包与杂货商店"]
		descriptions=["收割 → 脱粒 → 磨粉，风车带动磨坊","分级储粮与面粉配送","主粮与烘焙产品服务四镇居民"]
	if regions[index].theme=="flax":
		titles=["亚麻纺织工坊","布匹集散仓库","布料商店"]
		descriptions=["亚麻采收 → 处理纤维 → 纺线 → 织布","布包整理、晾晒与外运","本地亚麻布供应城镇衣物与日用品"]
	for i in range(3):
		interaction_areas[i].position=c+positions[i]
		interaction_areas[i].set_meta("title",titles[i])
		interaction_areas[i].set_meta("description",regions[index].description+"\n\n"+descriptions[i]+"\n\nE / Esc 关闭")
	if not visited.has(regions[index].id): visited.append(regions[index].id)
	if region_label!=null: region_label.text=regions[index].name+"  /  "+regions[index].industry+"\nWASD 行走 · Shift 快走 · F 跟随 · H 房屋近景 · B 山麓远景 · V 商业街视角 · M 区域地图 · E 查看 · P 隐藏界面"
	for i in range(lod_towns.size()): lod_towns[i].visible=i!=index

func travel_to(index: int,teleport:=true) -> void:
	if travel_busy or index<0 or index>=regions.size(): return
	travel_busy=true
	if index!=active_index:
		var resource: PackedScene=load(regions[index].scene)
		var next:=resource.instantiate()
		for child in next.get_children():
			if child is Camera3D or child is WorldEnvironment or child is DirectionalLight3D or child is NavigationRegion3D: child.free()
		next.position=center(index)
		active_chunk.free()
		active_chunk=next
		add_child(active_chunk)
		landscape.decorate_town(active_chunk)
		street.decorate(active_chunk,regions[index].theme)
		roofs.decorate(active_chunk)
		vineyard.decorate(active_chunk,regions[index].theme)
		houses.decorate(active_chunk)
		roads.decorate(active_chunk)
	place_actors(index,teleport)
	region_map.hide()
	info_panel.hide()
	info_open=false
	travel_busy=false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_M:
			ui_layer.show()
			photo_mode=false
			region_map.visible=not region_map.visible
			region_map.refresh()
			return
		if region_map.visible:
			if event.keycode==KEY_ESCAPE: region_map.hide()
			if event.keycode>=KEY_1 and event.keycode<=KEY_4: travel_to(event.keycode-KEY_1)
			return
		if event.keycode==KEY_HOME:
			camera.position=center(active_index)+Vector3(78,100,107)
			camera.look_at(center(active_index)+Vector3(-7,0,-14))
			camera.size=76
			follow_player=false
			return
		if event.keycode==KEY_B:
			camera.position=Vector3(35,175,-155)
			camera.look_at(Vector3(-135,15,-365))
			camera.size=330
			follow_player=false
			return
		if event.keycode==KEY_H:
			camera.position=center(active_index)+Vector3(14,24,-17)
			camera.look_at(center(active_index)+Vector3(-12,4,18))
			camera.size=26
			follow_player=false
			return
		if event.keycode==KEY_V:
			camera.position=center(active_index)+Vector3(24,40,-40)
			camera.look_at(center(active_index)+Vector3(-12,2,16))
			camera.size=45
			follow_player=false
			return
	super._unhandled_input(event)

func _physics_process(delta: float) -> void:
	if player==null or region_map==null: return
	world_time+=delta
	elapsed+=delta
	var move:=Vector3.ZERO
	if not region_map.visible and not info_open:
		var input:=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		var right:=camera.global_basis.x
		var forward:=camera.global_basis.z
		right.y=0
		forward.y=0
		move=(right.normalized()*input.x+forward.normalized()*input.y).normalized()
	var speed:=9.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 5.0
	player.velocity.x=move.x*speed
	player.velocity.z=move.z*speed
	player.velocity.y-=20*delta
	player.move_and_slide()
	player.position.x=clampf(player.position.x,-498,418)
	player.position.z=clampf(player.position.z,-498,498)
	animate_person(player)
	if not region_map.visible:
		var pan:=Vector3(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),0,float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
		if pan.length()>0: follow_player=false
		camera.position+=pan*30*delta
		if follow_player:
			camera.position=camera.position.lerp(player.position+Vector3(40,48,56),delta*4)
			camera.look_at(camera.position-Vector3(40,48,56))
			camera.size=lerpf(camera.size,32,delta*3)
	update_world_walkers(delta)
	for rotor in get_tree().get_nodes_in_group("mill_sails"): rotor.rotate_z(delta*0.24)
	var nearby:=nearby_interaction()
	status_label.text="E 查看："+str(nearby.get_meta("title")) if nearby!=null else "已到访 %d / 4 镇 · M 打开区域地图 · 可沿路步行或选择镇间旅行"%visited.size()
	if not checking:
		update_streaming()
	if checking and world_time>3 and not captured:
		captured=true
		verify_world()

func update_streaming() -> void:
	for i in range(4):
		if i!=active_index and Vector2(player.position.x-center(i).x,player.position.z-center(i).z).length()<130: travel_to(i,false)

func update_world_walkers(delta: float) -> void:
	if world_time<0.3: return
	var c:=center(active_index)
	for body in walkers:
		var agent: NavigationAgent3D=body.get_node("Agent")
		if agent.is_navigation_finished() or not body.has_meta("started"):
			var east: bool=not bool(body.get_meta("going_east"))
			body.set_meta("going_east",east)
			body.set_meta("started",true)
			agent.target_position=Vector3(c.x+(65 if east else -65),0.05,body.position.z)
		var next:=agent.get_next_path_position()
		var direction:=next-body.position
		direction.y=0
		direction=direction.normalized()
		body.velocity.x=direction.x*1.4
		body.velocity.z=direction.z*1.4
		body.velocity.y-=20*delta
		body.move_and_slide()
		animate_person(body)

func verify_world() -> void:
	var results: Array=[]
	for index in range(4):
		travel_to(index)
		await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		var smoke_nodes: Array=[]
		for node in active_chunk.get_node("RoofDetailsV6").get_children():
			if node.get_script()==load("res://smoke_v6.gd"): smoke_nodes.append(node)
		var smoke_before: Vector3=smoke_nodes[0].particles[0].position if not smoke_nodes.is_empty() else Vector3.ZERO
		await get_tree().process_frame
		await get_tree().process_frame
		var smoke_moving: bool=smoke_nodes.size()==6 and not smoke_nodes[0].particles[0].position.is_equal_approx(smoke_before)
		var c:=center(index)
		var wall:=player.test_move(Transform3D(Basis.IDENTITY,c+Vector3(-24,1.1,-24)),Vector3(0,0,-5))
		var gate:=not player.test_move(Transform3D(Basis.IDENTITY,c+Vector3(-24,1.1,-5)),Vector3(0,0,-7))
		player.position=interaction_areas[0].position
		await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().process_frame
		var trigger:=interaction_areas[0].overlaps_body(player)
		var route:=NavigationServer3D.map_get_path(nav.get_navigation_map(),c+Vector3(14,0.05,0),center((index+1)%4)+Vector3(14,0.05,0),true)
		var nav_clear:=route.size()>1
		var elm_count:=0
		for node in active_chunk.get_children():
			if node is Sprite3D and node.texture==landscape.texture: elm_count+=1
		var tree_blocks:=player.test_move(Transform3D(Basis.IDENTITY,c+Vector3(-44,1.1,-26)),Vector3(0,0,-5))
		var vegetation_count:=0
		var vegetation_restored:=true
		for node in active_chunk.get_children():
			if node is MultiMeshInstance3D and node.get_script()!=null:
				var positions: Array=node.get("placements")
				vegetation_count+=positions.size()
				if node.multimesh.instance_count!=positions.size(): vegetation_restored=false
				if DisplayServer.get_name()!="headless" and not positions.is_empty():
					if not node.multimesh.get_instance_transform(0).origin.is_equal_approx(positions[0].origin): vegetation_restored=false
		for i in range(route.size()-1):
			var hit:=KinematicCollision3D.new()
			if player.test_move(Transform3D(Basis.IDENTITY,route[i]+Vector3(0,1.05,0)),route[i+1]-route[i],hit):
				nav_clear=false
				print("PATH_BLOCK ",index," ",route[i]," -> ",route[i+1]," hit ",hit.get_position()," collider ",hit.get_collider().get_parent().global_position)
		results.append({"region":regions[index].id,"theme":regions[index].theme,"chunk_position":[active_chunk.position.x,active_chunk.position.z],"wall_collision":wall,"gate_clear":gate,"interaction_trigger":trigger,"route_to_next_points":route.size(),"route_clear":nav_clear,"elm_sprites":elm_count,"elm_collision":tree_blocks,"elm_restored":elm_count==10,"road_details_ready":active_chunk.has_node("RoadDetailsV10") and active_chunk.get_node("RoadDetailsV10").get_meta("rounded_corners")==4,"house_detail_ready":active_chunk.has_node("PixelHousesV9") and active_chunk.get_node("PixelHousesV9").get_meta("houses")==18,"detailed_windows":active_chunk.get_node("PixelHousesV9").get_meta("detailed_windows"),"pixel_vines_ready":regions[index].theme!="wine" or (active_chunk.has_node("PixelVineyardV8") and active_chunk.get_node("PixelVineyardV8").get_child_count()==72),"lod_visibility":not lod_towns[index].visible and lod_towns[(index+1)%4].visible,"smoke_animated":smoke_moving,"roofs_ready":active_chunk.has_node("RoofDetailsV6") and active_chunk.get_node("RoofDetailsV6").get_meta("roof_count")==18 and active_chunk.get_node("RoofDetailsV6").get_meta("old_roofs_hidden")==18,"storefronts_ready":active_chunk.has_node("StreetDetailsV5") and active_chunk.get_node("StreetDetailsV5").get_meta("storefronts")==6,"vegetation_instances":vegetation_count,"vegetation_restored":vegetation_restored and vegetation_count>(300 if regions[index].theme=="wine" else 800)})
		if DisplayServer.get_name()!="headless":
			ui_layer.hide()
			camera.position=c+Vector3(-19,0,-25)+Vector3(48,58,69)
			camera.look_at(c+Vector3(-19,0,-25))
			camera.size=57
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://world_%s.png"%regions[index].id)
			ui_layer.show()
	if DisplayServer.get_name()!="headless":
		await capture_extra(Vector3(399,0,-263),57,"harbor")
		await capture_extra(Vector3(-236,0,-125),105,"countryside")
	travel_to(0)
	if DisplayServer.get_name()!="headless":
		ui_layer.hide()
		var view_event:=InputEventKey.new()
		view_event.keycode=KEY_V
		view_event.pressed=true
		_unhandled_input(view_event)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://world_street.png")
		view_event.keycode=KEY_H
		_unhandled_input(view_event)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://world_houses.png")
		await capture_extra(center(0)+Vector3(14,0,0),32,"roads")
		await capture_extra(center(0)+Vector3(-48,0,-43),30,"vineyard")
		ui_layer.hide()
		view_event.keycode=KEY_B
		_unhandled_input(view_event)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://world_mountains.png")
		ui_layer.show()
	player.position=center(2)+Vector3(110,1.2,0)
	var before:=player.position
	update_streaming()
	var stream_ok:=active_index==2 and player.position.is_equal_approx(before)
	# Exercise the actual map button callback as well as keyboard input.
	region_map.get_child(3).pressed.emit()
	var map_button_ok:=active_index==3
	var event:=InputEventKey.new()
	event.keycode=KEY_M
	event.pressed=true
	_unhandled_input(event)
	var map_key_ok:=region_map.visible
	event=InputEventKey.new()
	event.keycode=KEY_1
	event.pressed=true
	_unhandled_input(event)
	var back_ok:=active_index==0 and active_chunk.position==center(0)
	var coast_ok:=player.test_move(Transform3D(Basis.IDENTITY,Vector3(418,1.1,-250)),Vector3(4,0,0))
	var ridge_ok: bool=farfield.verify_mountains()
	var all_ok: bool=vineyard.alpha_valid and ridge_ok and coast_ok and landscape.alpha_valid and landscape.parcels.size()==20 and back_ok and visited.size()==4 and stream_ok and map_button_ok and map_key_ok
	for result in results:
		for key in ["wall_collision","gate_clear","interaction_trigger","route_clear","vegetation_restored","elm_collision","elm_restored","storefronts_ready","roofs_ready","smoke_animated","lod_visibility","pixel_vines_ready","house_detail_ready","road_details_ready"]:
			if not result[key]: all_ok=false
	world_results={"version":10,"extent_m":[1000,1000],"regions":results,"trellis_alpha_valid":vineyard.alpha_valid,"reference_atlas_has_alpha":vineyard.reference_has_alpha,"mountain_collision":ridge_ok,"distant_mesh_batches":3,"coast_collision":coast_ok,"tree_alpha_valid":landscape.alpha_valid,"rural_parcels":landscape.parcels.size(),"visited_count":visited.size(),"return_trip_ok":back_ok,"walk_in_streaming_preserves_position":stream_ok,"map_button_travel":map_button_ok,"map_keyboard_toggle":map_key_ok,"all_passed":all_ok,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method()}
	FileAccess.open("res://world_verification.json",FileAccess.WRITE).store_string(JSON.stringify(world_results,"\t"))
	var global_buildings: Array=[]
	for region in regions:
		for b in footprints:
			var record: Dictionary=b.duplicate()
			record.id=region.id+"/"+b.id
			record.x=b.x+region.center[0]
			record.z=b.z+region.center[1]
			global_buildings.append(record)
	var vertices: Array=[]
	for vertex in nav.navigation_mesh.vertices: vertices.append([vertex.x,vertex.y,vertex.z])
	var polygons: Array=[]
	for i in range(nav.navigation_mesh.get_polygon_count()): polygons.append(Array(nav.navigation_mesh.get_polygon(i)))
	FileAccess.open("res://world_logic.json",FileAccess.WRITE).store_string(JSON.stringify({"version":10,"units":"metres","extent":[1000,1000],"transform":"X=E-500,Y=height,Z=500-N","region_layout":"fictional design; no registration","regions":regions,"buildings":global_buildings,"agriculture_parcels":landscape.parcels,"navigation":{"vertices":vertices,"polygons":polygons,"scope":"four connected road corridors","character_radius":0.35,"character_height":1.8},"water_blocked_x":[420,500],"streaming_radius":130},"\t"))
	farfield.save_logic()
	vineyard.save_logic()
	print(JSON.stringify(world_results))
	if DisplayServer.get_name()!="headless":
		region_map.show()
		region_map.refresh()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://world_map.png")
	get_tree().quit(0 if all_ok else 1)

func water_material() -> ShaderMaterial:
	var material:=ShaderMaterial.new()
	material.shader=load("res://water.gdshader")
	return material

func capture_extra(target: Vector3,size_m: float,label: String) -> void:
	ui_layer.hide()
	camera.position=target+Vector3(48,58,69)
	camera.look_at(target)
	camera.size=size_m
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://world_%s.png"%label)
	ui_layer.show()
