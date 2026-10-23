extends RefCounted

var world: Node3D
var root: Node3D
var slate: ShaderMaterial
var iron: Material
var clay: Material

func _init(host: Node3D) -> void:
	world=host
	slate=ShaderMaterial.new()
	slate.shader=load("res://slate_v6.gdshader")
	iron=world.mat("v6_lead",Color("41494b"))
	clay=world.mat("v6_clay",Color("86533c"))

func block(p: Vector3,size: Vector3,material: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	node.mesh=mesh
	node.position=p
	node.material_override=material
	root.add_child(node)
	return node

func tube(p: Vector3,radius: float,height: float,material: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var mesh:=CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=10
	node.mesh=mesh
	node.position=p
	node.material_override=material
	root.add_child(node)
	return node

func decorate(chunk: Node3D) -> void:
	root=Node3D.new()
	root.name="RoofDetailsV6"
	chunk.add_child(root)
	var old_roofs:=0
	for node in chunk.get_children():
		if node is MeshInstance3D and node.mesh is ArrayMesh and node.material_override is ShaderMaterial:
			if node.material_override.get_shader_parameter("slate")==true:
				node.hide()
				old_roofs+=1
	var index:=0
	var smoke_count:=0
	for b in world.footprints:
		build_roof(b)
		if index in [0,1,3,7,11,15]:
			var smoke:=Node3D.new()
			smoke.set_script(load("res://smoke_v6.gd"))
			smoke.position=Vector3(b.x-b.width*0.3-0.22,b.height+5.5,b.z-1)
			root.add_child(smoke)
			smoke_count+=1
		index+=1
	root.set_meta("roof_count",index)
	root.set_meta("old_roofs_hidden",old_roofs)
	root.set_meta("smoke_emitters",smoke_count)

func build_roof(b: Dictionary) -> void:
	var x: float=b.x
	var z: float=b.z
	var h: float=b.height
	var width: float=b.width+0.8
	var depth: float=b.depth+0.8
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Explicit outward normals: each slope stays flat, with a hard ridge.
	for side in [-1.0,1.0]:
		var a:=Vector3(-width/2,0,side*depth/2)
		var c:=Vector3(width/2,0,side*depth/2)
		var u:=Vector3(-width/2,3,0)
		var v:=Vector3(width/2,3,0)
		surface.set_normal(Vector3(0,depth/2,side*3).normalized())
		for point in [a,u,v,a,v,c]: surface.add_vertex(point)
	var node:=MeshInstance3D.new()
	node.name="FlatSlateRoof"
	node.mesh=surface.commit()
	node.position=Vector3(x,h,z)
	node.material_override=slate
	root.add_child(node)
	# Brick gable faces, rather than slate wrapping over the vertical ends.
	var gable:=SurfaceTool.new()
	gable.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		gable.set_normal(Vector3(side,0,0))
		for point in [Vector3(side*(width/2-0.3),0,-depth/2),Vector3(side*(width/2-0.3),3,0),Vector3(side*(width/2-0.3),0,depth/2)]: gable.add_vertex(point)
	var ends:=MeshInstance3D.new()
	ends.mesh=gable.commit()
	ends.position=Vector3(x,h,z)
	ends.material_override=world.mat("v6_gable",Color("874d37"),true)
	root.add_child(ends)
	for i in range(int(width/0.48)):
		var cap:=tube(Vector3(x-width/2+0.24+i*0.48,h+3.02,z),0.15,0.46,iron)
		cap.rotation.z=PI/2
	for side in [-1.0,1.0]:
		block(Vector3(x,h-0.03,z+side*depth/2),Vector3(width,0.16,0.18),iron)
		for xx in [x-width/2,x+width/2]:
			var edge:=block(Vector3(xx,h+1.5,z+side*depth/4),Vector3(0.13,0.12,sqrt(9.0+depth*depth/4)),iron)
			edge.rotation.x=side*atan2(3,depth/2)
	for cx in [x-b.width*0.3,x+b.width*0.3]:
		for dx in [-0.22,0.22]:
			tube(Vector3(cx+dx,h+5.0,z-1),0.15,0.8,clay)
			tube(Vector3(cx+dx,h+5.4,z-1),0.19,0.1,clay)
			tube(Vector3(cx+dx,h+5.46,z-1),0.12,0.02,world.mat("v6_soot",Color("1d2020")))
