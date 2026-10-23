extends RefCounted

var world: Node3D
var root: Node3D
var stone: Material
var iron: Material
var dark: Material

func _init(host: Node3D) -> void:
	world=host
	stone=world.mat("road_curb_v10",Color("b5a184"))
	iron=world.mat("road_iron_v10",Color("453d32"))
	dark=world.mat("road_drain_v10",Color("171f21"))

func block(p: Vector3,s: Vector3,m: Material) -> void:
	var node:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=s
	node.mesh=mesh
	node.position=p
	node.material_override=m
	root.add_child(node)

func decorate(chunk: Node3D) -> void:
	# Retire only the original sidewalk strips and curb blocks, preserving buildings.
	for node in chunk.find_children("*","MeshInstance3D",true,false):
		if not node.mesh is BoxMesh: continue
		var s: Vector3=node.mesh.size
		var p: Vector3=node.position
		if (s.is_equal_approx(Vector3(160,0.16,2)) and is_equal_approx(abs(p.z),5)) or (s.is_equal_approx(Vector3(2,0.16,120)) and (is_equal_approx(p.x,11) or is_equal_approx(p.x,17))): node.hide()
		if s.is_equal_approx(Vector3(1.97,0.2,0.15)) and is_equal_approx(abs(p.z),4.1): node.hide()
	root=Node3D.new()
	root.name="RoadDetailsV10"
	chunk.add_child(root)
	var paving: Material=world.surface_material(true)
	# End straight sidewalks at the tangent points of four radius-two corners.
	for z in [-5.0,5.0]:
		block(Vector3(-35,0.08,z),Vector3(90,0.16,2),paving)
		block(Vector3(49,0.08,z),Vector3(62,0.16,2),paving)
	for x in [11.0,17.0]:
		for z in [-33.0,33.0]: block(Vector3(x,0.08,z),Vector3(2,0.16,54),paving)
	for sx in [-1.0,1.0]:
		for sz in [-1.0,1.0]: corner(Vector2(14+sx*4,sz*6),-sx,-sz,paving)
	for z in [-4.0,4.0]:
		for x in range(-79,80):
			if x>=10 and x<18: continue
			block(Vector3(x+0.5,0.11,z),Vector3(0.97,0.22,0.18),stone)
	for x in [12.0,16.0]:
		for z in range(-60,60):
			if z>=-6 and z<6: continue
			block(Vector3(x,0.11,z+0.5),Vector3(0.18,0.22,0.97),stone)
	# Gutter setts and grates sit beside the clear traffic corridor.
	for z in [-3.78,3.78]:
		for x in range(-79,80):
			if x>=10 and x<18: continue
			block(Vector3(x+0.5,0.055,z),Vector3(0.96,0.028,0.26),iron)
		for x in [-60.0,-32.0,-4.0,28.0,56.0]:
			block(Vector3(x,0.075,z),Vector3(0.95,0.045,0.4),stone)
			block(Vector3(x,0.102,z),Vector3(0.79,0.015,0.30),dark)
			for k in range(7): block(Vector3(x-0.33+k*0.11,0.115,z),Vector3(0.035,0.018,0.3),iron)
	for p in [Vector2(-10,1.5),Vector2(38,-1.4),Vector2(14,-22)]: manhole(p)
	root.set_meta("rounded_corners",4)
	root.set_meta("drains",10)
	root.set_meta("manholes",3)

func corner(c: Vector2,sx: float,sz: float,paving: Material) -> void:
	block(Vector3(c.x+sx,0.02,c.y+sz),Vector3(2,0.04,2),world.surface_material(false))
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(16):
		var a:=float(i)*PI/32.0
		var b:=float(i+1)*PI/32.0
		var p:=Vector3(c.x+sx*cos(a)*2,0.16,c.y+sz*sin(a)*2)
		var q:=Vector3(c.x+sx*cos(b)*2,0.16,c.y+sz*sin(b)*2)
		var v:=Vector3(c.x,0.16,c.y)
		for point in ([v,q,p] if sx*sz<0 else [v,p,q]):
			surface.set_normal(Vector3.UP)
			surface.add_vertex(point)
		var curb:=MeshInstance3D.new()
		var mesh:=BoxMesh.new()
		mesh.size=Vector3(p.distance_to(q)+0.01,0.22,0.18)
		curb.mesh=mesh
		curb.position=(p+q)*0.5-Vector3(0,0.05,0)
		curb.rotation.y=-atan2(q.z-p.z,q.x-p.x)
		curb.material_override=stone
		root.add_child(curb)
	world.farfield.attach(root,surface,paving)

func manhole(p: Vector2) -> void:
	var node:=MeshInstance3D.new()
	var mesh:=CylinderMesh.new()
	mesh.top_radius=0.49
	mesh.bottom_radius=0.49
	mesh.height=0.025
	mesh.radial_segments=32
	node.mesh=mesh
	node.position=Vector3(p.x,0.072,p.y)
	node.material_override=iron
	root.add_child(node)
	for i in range(-3,4):
		var length:=sqrt(0.40*0.40-pow(i*0.1,2))*2
		block(Vector3(p.x+i*0.1,0.09,p.y),Vector3(0.028,0.015,length),dark)
	block(Vector3(p.x,0.10,p.y),Vector3(0.8,0.012,0.035),stone)
