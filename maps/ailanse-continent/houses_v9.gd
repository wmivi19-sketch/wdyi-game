extends RefCounted

var world: Node3D
var batches: Dictionary={}
var materials: Dictionary={}
var window_count:=0
var detail_root: Node3D

func _init(host: Node3D) -> void:
	world=host
	materials["stone"]=world.mat("v9_sandstone",Color("b1a187"))
	materials["wood"]=world.mat("v9_windowwood",Color("304138"))
	materials["shadow"]=world.mat("v9_recess",Color("171f20"))
	materials["glass"]=world.mat("v9_amberglass",Color("c39d5b"),false,true)
	materials["dim"]=world.mat("v9_dimglass",Color("777c70"))
	materials["iron"]=world.mat("v9_gutter",Color("3c4140"))
	materials["leaf"]=world.mat("v9_leaf",Color("426032"))
	materials["flower"]=world.mat("v9_flower",Color("c6a35a"))

func piece(p: Vector3,size: Vector3,key: String) -> void:
	world.farfield.cuboid(batches[key],p,size)

func wall_piece(center: Vector3,offset: Vector3,size: Vector3,axis: int,side: float,key: String) -> void:
	if axis==0:
		piece(center+Vector3(offset.z*side,offset.y,offset.x),Vector3(size.z,size.y,size.x),key)
	else:
		piece(center+Vector3(offset.x,offset.y,offset.z*side),size,key)

func window(center: Vector3,axis: int,side: float,lit: bool) -> void:
	window_count+=1
	wall_piece(center,Vector3(0,0,0.03),Vector3(1.28,1.94,0.14),axis,side,"stone")
	wall_piece(center,Vector3(0,0,0.12),Vector3(1.04,1.68,0.12),axis,side,"shadow")
	wall_piece(center,Vector3(0,0,0.20),Vector3(0.84,1.44,0.06),axis,side,"glass" if lit else "dim")
	for xx in [-0.46,0,0.46]: wall_piece(center,Vector3(xx,0,0.25),Vector3(0.055,1.56,0.08),axis,side,"wood")
	for yy in [-0.75,-0.15,0.75]: wall_piece(center,Vector3(0,yy,0.25),Vector3(0.98,0.065,0.08),axis,side,"wood")
	wall_piece(center,Vector3(0,-0.98,0.17),Vector3(1.48,0.14,0.5),axis,side,"stone")
	wall_piece(center,Vector3(0,1.04,0.08),Vector3(1.45,0.16,0.27),axis,side,"stone")
	wall_piece(center,Vector3(0,1.13,0.16),Vector3(0.24,0.22,0.27),axis,side,"stone")
	for xx in [-0.42,0.42]: wall_piece(center,Vector3(xx,-1.12,0.08),Vector3(0.16,0.2,0.24),axis,side,"stone")

func decorate(chunk: Node3D) -> void:
	batches={}
	window_count=0
	for key in materials:
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[key]=surface
	var root:=Node3D.new()
	root.name="PixelHousesV9"
	chunk.add_child(root)
	detail_root=root
	var house_count:=0
	var colors: Array[Color]=[Color("985e43"),Color("875140"),Color("a36949"),Color("785343"),Color("92583e")]
	for b in world.footprints:
		var material:=ShaderMaterial.new()
		material.shader=load("res://pixel_brick_v9.gdshader")
		material.set_shader_parameter("brick_color",Color("a79d86") if b.id=="export_warehouse" else colors[house_count%colors.size()])
		material.set_shader_parameter("stone",b.id=="export_warehouse")
		# Replace the actual wall material, preserving its existing collision children.
		for node in chunk.get_children():
			if node is MeshInstance3D and node.mesh is BoxMesh and node.position.is_equal_approx(Vector3(b.x,b.height/2,b.z)) and node.mesh.size.is_equal_approx(Vector3(b.width,b.height,b.depth)):
				node.material_override=material
				house_count+=1
		var x: float=b.x
		var z: float=b.z
		var w: float=b.width
		var d: float=b.depth
		var h: float=b.height
		for side in [-1.0,1.0]:
			for column in range(int(d/3)):
				for floor_index in range(int(h/3)):
					window(Vector3(x+side*(w/2+0.04),1.8+floor_index*3,z-d/2+1.5+column*3),0,side,(column+floor_index+house_count)%4!=0)
		# Complete rear elevations of houses that do not have the v5 north-facing shopfront.
		if not str(b.id).begins_with("row_") and b.id!="wine_merchant":
			for column in range(int(w/2.8)):
				for floor_index in range(int(h/3)):
					window(Vector3(x-w/2+1.5+column*2.8,1.8+floor_index*3,z-d/2-0.04),2,-1,(column+floor_index)%3!=0)
		for side in [-1.0,1.0]:
			# Paired mouldings and dentils wrap around side elevations.
			for yy in [h-0.42,h-0.13]: piece(Vector3(x+side*(w/2+0.12),yy,z),Vector3(0.32,0.12,d+0.4),"stone")
			for j in range(int(d/0.65)):
				piece(Vector3(x+side*(w/2+0.18),h-0.30,z-d/2+0.3+j*0.65),Vector3(0.32,0.18,0.14),"stone")
			piece(Vector3(x+side*(w/2+0.18),h/2,z-d/2+0.3),Vector3(0.09,h,0.09),"iron")
		for cx in [x-w*0.3,x+w*0.3]:
			for yy in [h+3.65,h+3.95]: piece(Vector3(cx,yy,z-1),Vector3(1.04,0.12,1.04),"stone")
		# Divide dormer glass into four panes without changing its silhouette.
		for xx in [x-w*0.28,x+w*0.28]:
			piece(Vector3(xx,h+1.7,z+d*0.28+0.67),Vector3(0.06,1.1,0.08),"wood")
			piece(Vector3(xx,h+1.7,z+d*0.28+0.67),Vector3(0.9,0.06,0.08),"wood")
		# Window boxes and corner stonework carry detail onto both visible elevations.
		for side in [-1.0,1.0]:
			for yy in range(1,int(h/0.6)):
				for zz in [z-d/2+0.14,z+d/2-0.14]: piece(Vector3(x+side*(w/2+0.07),yy*0.6,zz),Vector3(0.28,0.24,0.65 if yy%2 else 0.42),"stone")
		for xx in [x-w*0.28,x+w*0.28]:
			for side in [-1.0,1.0]:
				var p:=Vector3(xx,3.85,z+side*(d/2+0.45))
				piece(p,Vector3(1.5,0.34,0.55),"wood")
				for k in range(9):
					piece(p+Vector3(-0.65+k*0.16,0.26+(k%3)*0.04,0),Vector3(0.22,0.23,0.35),"leaf")
					piece(p+Vector3(-0.65+k*0.16,0.4+(k%3)*0.04,side*0.12),Vector3(0.1,0.07,0.1),"flower")
		if b.id=="wine_merchant": mansard(chunk,b)
		if b.id=="winery":
			gable(Vector3(x,h-0.6,z+d/2+0.15),false,1.0)
	for key in batches:
		materials[key].cull_mode=BaseMaterial3D.CULL_DISABLED
		world.farfield.attach(root,batches[key],materials[key])
	root.set_meta("houses",house_count)
	root.set_meta("detailed_windows",window_count)
	root.set_meta("landmark_roofs",2)

func beam(a: Vector3,b: Vector3,width: float,key: String) -> void:
	var node:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=Vector3(width,a.distance_to(b),width)
	node.mesh=mesh
	node.position=(a+b)/2
	var direction: Vector3=(b-a).normalized()
	var right:=direction.cross(Vector3.FORWARD).normalized()
	if right.length()<0.1: right=direction.cross(Vector3.RIGHT).normalized()
	node.basis=Basis(right,direction,right.cross(direction).normalized())
	node.material_override=materials[key]
	detail_root.add_child(node)

func gable(p: Vector3,ornate: bool,side: float) -> void:
	var outline: Array[Vector2]=[Vector2(-2.0,0),Vector2(-2.0,1.7),Vector2(-1.5,1.7),Vector2(-1.35,2.7),Vector2(-0.7,2.9),Vector2(0,3.7),Vector2(0.7,2.9),Vector2(1.35,2.7),Vector2(1.5,1.7),Vector2(2,1.7),Vector2(2,0)]
	if not ornate: outline=[Vector2(-2,0),Vector2(-2,2.0),Vector2(0,3.9),Vector2(2,2),Vector2(2,0)]
	var polygon:=PackedVector2Array(outline)
	var triangles:=Geometry2D.triangulate_polygon(polygon)
	var mesh:=SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_normal(Vector3(0,0,side))
	for index in triangles: mesh.add_vertex(p+Vector3(outline[index].x,outline[index].y,0))
	var face:=MeshInstance3D.new()
	face.mesh=mesh.commit()
	face.material_override=materials["stone"] if ornate else world.mat("v9_gablebrick",Color("965637"),true)
	detail_root.add_child(face)
	for i in range(outline.size()-1):
		beam(p+Vector3(outline[i].x,outline[i].y,side*0.12),p+Vector3(outline[i+1].x,outline[i+1].y,side*0.12),0.19,"stone")
	window(p+Vector3(0,1.1,side*0.13),2,side,true)
	for i in range(13):
		var angle: float=i*PI/12
		var a:=p+Vector3(cos(angle)*0.72,1.78+sin(angle)*0.72,side*0.4)
		piece(a,Vector3(0.2,0.2,0.22),"stone")
	beam(p+Vector3(0,3.65,0),p+Vector3(0,4.1,0),0.14,"iron")

func mansard(chunk: Node3D,b: Dictionary) -> void:
	var x: float=b.x
	var z: float=b.z
	var h: float=b.height
	var w: float=b.width+0.8
	var d: float=b.depth+0.8
	for node in chunk.get_children():
		if node is MeshInstance3D and node.mesh is CylinderMesh and node.position.is_equal_approx(Vector3(x,h+3,z)):
			node.hide()
	# Replace only this building's roof slopes and old ridge decorations.
	for node in chunk.get_node("RoofDetailsV6").get_children():
		if node is MeshInstance3D and absf(node.position.x-x)<w/2+0.1 and absf(node.position.z-z)<d/2+0.1:
			if node.mesh is ArrayMesh or node.position.y<h+4: node.hide()
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bottom: Array[Vector3]=[Vector3(-w/2,0,-d/2),Vector3(w/2,0,-d/2),Vector3(w/2,0,d/2),Vector3(-w/2,0,d/2)]
	var top: Array[Vector3]=[]
	for corner in bottom: top.append(Vector3(corner.x-signf(corner.x)*2,3.2,corner.z-signf(corner.z)*2))
	for i in range(4):
		var j: int=(i+1)%4
		var normal: Vector3=(top[i]-bottom[i]).cross(bottom[j]-bottom[i]).normalized()
		if normal.y<0: normal=-normal
		surface.set_normal(normal)
		for v in [bottom[i],top[i],top[j],bottom[i],top[j],bottom[j]]: surface.add_vertex(v)
		beam(Vector3(x,h,z)+bottom[i],Vector3(x,h,z)+bottom[j],0.15,"stone")
		beam(Vector3(x,h,z)+top[i],Vector3(x,h,z)+top[j],0.12,"iron")
		beam(Vector3(x,h,z)+bottom[i],Vector3(x,h,z)+top[i],0.1,"iron")
	surface.set_normal(Vector3.UP)
	for i in [0,1,2,0,2,3]: surface.add_vertex(top[i])
	var roof:=MeshInstance3D.new()
	roof.mesh=surface.commit()
	roof.position=Vector3(x,h,z)
	roof.material_override=world.roofs.slate
	detail_root.add_child(roof)
	for side in [-1.0,1.0]: gable(Vector3(x,h-0.5,z+side*(d/2+0.08)),true,side)
