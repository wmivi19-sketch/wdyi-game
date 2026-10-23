extends RefCounted

var world: Node3D
var mountain: MeshInstance3D
var probes: Array[Vector3]=[]
var heights: Array=[]

func _init(host: Node3D) -> void:
	world=host

func height_at(x: float,z: float) -> float:
	var north:=clampf((-z-410.0)/90.0,0,1)
	var ridge:=0.5+0.5*cos((north-0.61)*PI*1.6)
	var peaks:=26.0+18.0*pow(absf(sin(x*0.023+0.6)),3)+14.0*pow(absf(sin(x*0.047)),4)
	var detail:=5.0*sin(x*0.13+north*8)+3.0*cos(x*0.071-north*15)
	var ends:=smoothstep(-500.0,-460.0,x)*(1.0-smoothstep(365.0,412.0,x))
	return maxf(0,(peaks*ridge+detail)*smoothstep(0.0,0.28,north)*ends)

func build_mountains() -> void:
	var vertices: Array[Vector3]=[]
	for row in range(10):
		var values: Array=[]
		for col in range(77):
			var x: float=-500+col*12
			var z: float=-410-row*10
			var h:=height_at(x,z)
			vertices.append(Vector3(x,h,z))
			values.append(h)
			if row==5 and col in [12,38,62]: probes.append(Vector3(x,h,z))
		heights.append(values)
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for row in range(9):
		for col in range(76):
			var i:=row*77+col
			for index in [i,i+77,i+1,i+1,i+77,i+78]:
				var p:=vertices[index]
				var shade:=clampf(p.y/60.0,0,1)
				surface.set_color(Color("555c47").lerp(Color("a49b80"),shade))
				surface.add_vertex(p)
	surface.generate_normals()
	mountain=MeshInstance3D.new()
	mountain.name="FlorinsRidge"
	mountain.mesh=surface.commit()
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.roughness=0.95
	mountain.material_override=material
	world.add_child(mountain)
	mountain.create_trimesh_collision()

func face(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,normal: Vector3) -> void:
	surface.set_normal(normal)
	for p in [a,b,c]: surface.add_vertex(p)

func cuboid(surface: SurfaceTool,p: Vector3,s: Vector3) -> void:
	var half:=s/2
	for axis in range(3):
		var u:=(axis+1)%3
		var v:=(axis+2)%3
		for side in [-1.0,1.0]:
			var normal:=Vector3.ZERO
			normal[axis]=side
			var corners: Array[Vector3]=[]
			for pair in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var point:=p
				point[axis]+=half[axis]*side
				point[u]+=half[u]*pair.x
				point[v]+=half[v]*pair.y
				corners.append(point)
			face(surface,corners[0],corners[1],corners[2],normal)
			face(surface,corners[0],corners[2],corners[3],normal)

func attach(root: Node3D,surface: SurfaceTool,material: Material) -> void:
	var node:=MeshInstance3D.new()
	node.mesh=surface.commit()
	node.material_override=material
	root.add_child(node)

func make_town(index: int) -> Node3D:
	var root:=Node3D.new()
	root.name="DistantTown_%d"%index
	root.position=world.center(index)
	world.add_child(root)
	var walls:=SurfaceTool.new()
	var roofs:=SurfaceTool.new()
	var windows:=SurfaceTool.new()
	for surface in [walls,roofs,windows]: surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in world.footprints:
		var x: float=b.x
		var z: float=b.z
		var w: float=b.width
		var d: float=b.depth
		var h: float=b.height
		cuboid(walls,Vector3(x,h/2,z),Vector3(w,h,d))
		for side in [-1.0,1.0]:
			var a:=Vector3(x-w/2-0.4,h,z+side*(d/2+0.4))
			var c:=Vector3(x+w/2+0.4,h,z+side*(d/2+0.4))
			var u:=Vector3(x-w/2-0.4,h+3,z)
			var v:=Vector3(x+w/2+0.4,h+3,z)
			var normal:=Vector3(0,d/2+0.4,side*3).normalized()
			face(roofs,a,u,v,normal)
			face(roofs,a,v,c,normal)
			face(walls,Vector3(x+side*w/2,h,z-d/2),Vector3(x+side*w/2,h+3,z),Vector3(x+side*w/2,h,z+d/2),Vector3(side,0,0))
			for yy in range(int(h/3)):
				for xx in range(int(w/2.8)):
					cuboid(windows,Vector3(x-w/2+1.5+xx*2.8,1.8+yy*3,z+side*(d/2+0.05)),Vector3(0.9,1.45,0.1))
		for xx in [-0.3,0.3]: cuboid(walls,Vector3(x+w*xx,h+2.5,z-1),Vector3(0.9,4,0.9))
	var brick: Material=world.mat("v7_distant_brick",Color("874d37"),true)
	var roofmat:=StandardMaterial3D.new()
	roofmat.albedo_color=Color("293641")
	roofmat.cull_mode=BaseMaterial3D.CULL_DISABLED
	roofmat.roughness=0.9
	var glass:=StandardMaterial3D.new()
	glass.albedo_color=Color("c89e5e")
	glass.emission_enabled=true
	glass.emission=Color("996d34")
	glass.emission_energy_multiplier=0.15
	glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	attach(root,walls,brick)
	attach(root,roofs,roofmat)
	attach(root,windows,glass)
	root.set_meta("buildings",world.footprints.size())
	root.set_meta("mesh_batches",3)
	root.visible=index!=world.active_index
	return root

func verify_mountains() -> bool:
	for p in probes:
		var query:=PhysicsRayQueryParameters3D.create(p+Vector3(0,100,0),p-Vector3(0,100,0),1)
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or absf(hit.position.y-p.y)>0.05: return false
	return probes.size()==3

func save_logic() -> void:
	FileAccess.open("res://farfield_logic.json",FileAccess.WRITE).store_string(JSON.stringify({"version":7,"units":"metres","terrain_source":"fictional designed ridge, no DEM","grid_origin_xz":[-500,-410],"grid_step_xz":[12,-10],"columns":77,"rows":10,"height_samples":heights,"collision":"trimesh from the same visual mesh","road_north_end_z":-389,"mountain_front_z":-410,"distant_town_batches":3,"distant_buildings_per_town":18},"\t"))
