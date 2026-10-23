extends RefCounted

var world: Node3D
var root: Node3D
var green: Material
var cream: Material
var iron: Material
var glass: Material
var wood: Material
var leaf_mesh: ArrayMesh

func _init(host: Node3D) -> void:
	world=host
	green=world.mat("v5_green",Color("294b39"))
	cream=world.mat("v5_cream",Color("c5b98e"))
	iron=world.mat("v5_iron",Color("252c2c"))
	glass=world.mat("v5_glass",Color("c59b57"),false,true)
	wood=world.mat("v5_wood",Color("705136"))
	leaf_mesh=make_leaves()

func block(p: Vector3,size: Vector3,material: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	node.mesh=mesh
	node.position=p
	node.material_override=material
	root.add_child(node)
	return node

func decorate(chunk: Node3D,theme: String) -> void:
	root=Node3D.new()
	root.name="StreetDetailsV5"
	chunk.add_child(root)
	var replaced:=0
	for node in chunk.get_children():
		if node is MultiMeshInstance3D and node.get_script()!=null and node.multimesh.mesh is SphereMesh and node.instance_colors.size()==node.placements.size():
			node.multimesh.mesh=leaf_mesh
			var material:=StandardMaterial3D.new()
			material.vertex_color_use_as_albedo=true
			material.cull_mode=BaseMaterial3D.CULL_DISABLED
			material.roughness=0.9
			node.material_override=material
			replaced+=node.placements.size()
	root.set_meta("leaf_instances",replaced)
	var storefronts:=0
	for building in world.footprints:
		if str(building.id).begins_with("row_") or building.id=="wine_merchant":
			storefront(building,theme,storefronts)
			storefronts+=1
	root.set_meta("storefronts",storefronts)
	# Garden edging and flowers are kept behind the walkable pavement.
	for x in [-48,-20,3,30,57]:
		for i in range(9):
			var flower: MeshInstance3D=block(Vector3(x-0.72+i*0.18,1.07,6.8),Vector3(0.12,0.1,0.14),world.mat("v5_flower_%d"%(i%3),[Color("c9a053"),Color("aa5e5b"),Color("b4b789")][i%3]))
			flower.rotation.y=i*0.7
		block(Vector3(x+3,1.05,7.25),Vector3(1.8,0.18,0.12),wood)
		block(Vector3(x+3,0.8,7.25),Vector3(1.8,0.18,0.12),wood)
	# Stone walkway through the winery forecourt; same elevation as paving.
	for z in range(-19,-7,2):
		for x in [-25,-23]: block(Vector3(x,0.048,z),Vector3(1.85,0.012,1.85),world.mat("v5_courtyard",Color("878273")))
	for x in [-37,-12,25,41]:
		block(Vector3(x,0.5,-8),Vector3(2.2,0.9,0.7),world.mat("v5_planter",Color("8c5e45"),true))
		for i in range(7):
			var leaves:=MeshInstance3D.new()
			leaves.mesh=leaf_mesh
			leaves.material_override=green
			leaves.position=Vector3(x-0.9+i*0.3,1.15,-8)
			leaves.scale=Vector3(0.35,0.35,0.35)
			root.add_child(leaves)

func storefront(b: Dictionary,theme: String,index: int) -> void:
	var x: float=b.x
	var front: float=b.z-b.depth/2-0.14
	var width: float=b.width-0.8
	var color: Material=green if index%2==0 else world.mat("v5_burgundy",Color("653b35"))
	block(Vector3(x,1.55,front),Vector3(width,3.1,0.25),color)
	block(Vector3(x,1.4,front-0.17),Vector3(1.2,2.8,0.15),wood)
	block(Vector3(x,2,front-0.26),Vector3(0.85,1.1,0.06),glass)
	block(Vector3(x+0.38,1.2,front-0.31),Vector3(0.08,0.1,0.08),cream)
	for side in [-1,1]:
		var xx: float=x+side*width*0.285
		var ww: float=width*0.36
		block(Vector3(xx,1.6,front-0.17),Vector3(ww,2.2,0.12),glass)
		for y in [0.55,1.35,2.7]: block(Vector3(xx,y,front-0.25),Vector3(ww+0.1,0.08,0.16),cream)
		for offset in [-0.5,0,0.5]: block(Vector3(xx+offset*ww,1.62,front-0.25),Vector3(0.07,2.1,0.16),color)
		for j in range(6):
			var product: Material=green if theme=="wine" else (cream if theme=="wheat" else world.mat("v5_cloth",Color("718d9c")))
			block(Vector3(xx-ww*0.4+j*ww*0.16,0.95,front-0.31),Vector3(0.17,0.48 if theme=="wine" else 0.3,0.16),product)
	# Sloped canvas stripes and hanging valance, above pedestrian headroom.
	for i in range(int(width/0.35)):
		var stripe: Material=cream if i%2 else color
		var panel:=block(Vector3(x-width/2+0.18+i*0.35,3.12,front-0.8),Vector3(0.35,0.08,1.8),stripe)
		panel.rotation.x=-0.15
		block(Vector3(panel.position.x,2.84,front-1.68),Vector3(0.35,0.24,0.08),stripe)
	for xx in [x-width/2,x+width/2]:
		var brace:=block(Vector3(xx,2.9,front-0.7),Vector3(0.06,0.06,1.5),iron)
		brace.rotation.x=-0.25
	block(Vector3(x,3.72,front-0.13),Vector3(width,0.66,0.2),color)
	for y in [3.38,4.06]: block(Vector3(x,y,front-0.26),Vector3(width,0.05,0.05),cream)
	var label:=Label3D.new()
	var labels: Array=["VINTNER & SONS","BOOKSELLER","TEA & GROCER","DRAPER","BAKERY","APOTHECARY"]
	if index==0: labels[0]="WINE MERCHANT" if theme=="wine" else ("FLOUR & PROVISIONS" if theme=="wheat" else "LINEN MERCHANT")
	label.text=labels[index%labels.size()]
	label.font_size=40
	label.pixel_size=0.007
	label.modulate=Color("ead8a4")
	label.outline_size=0
	label.position=Vector3(x,3.72,front-0.27)
	label.rotation.y=PI
	root.add_child(label)
	# Cornice brackets, upper shutters and wrought iron balcony.
	for j in range(8): block(Vector3(x-width/2+j*width/7,4.22,front-0.25),Vector3(0.16,0.25,0.35),cream)
	for xx in [x-2.8,x,x+2.8]:
		for yy in range(4,int(b.height),3):
			block(Vector3(xx,yy+0.8,front-0.1),Vector3(1.12,1.55,0.12),glass)
			for offset in [-0.6,0.6]: block(Vector3(xx+offset,yy+0.8,front-0.2),Vector3(0.09,1.7,0.12),cream)
			for offset in [-0.82,0.82]: block(Vector3(xx,yy+0.8+offset,front-0.2),Vector3(1.3,0.09,0.12),cream)
			block(Vector3(xx,yy+0.8,front-0.22),Vector3(0.05,1.6,0.1),color)
			block(Vector3(xx,yy+0.8,front-0.22),Vector3(1.2,0.06,0.1),color)
		for side in [-1,1]:
			block(Vector3(xx+side*0.82,4.8,front-0.07),Vector3(0.38,1.6,0.14),color)
			for k in range(5): block(Vector3(xx+side*0.82,4.2+k*0.25,front-0.16),Vector3(0.33,0.05,0.08),iron)
	block(Vector3(x,4.1,front-0.6),Vector3(2.5,0.12,1.0),cream)
	for j in range(11): block(Vector3(x-1.2+j*0.24,4.58,front-1.04),Vector3(0.035,0.95,0.035),iron)
	block(Vector3(x,5.06,front-1.04),Vector3(2.6,0.06,0.06),iron)

func make_leaves() -> ArrayMesh:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng:=RandomNumberGenerator.new()
	rng.seed=505
	for i in range(32):
		var center:=Vector3(rng.randf_range(-0.85,0.85),rng.randf_range(-0.6,0.65),rng.randf_range(-0.7,0.7))
		var rotation:=Basis.from_euler(Vector3(rng.randf_range(-0.8,0.8),rng.randf()*TAU,rng.randf_range(-0.8,0.8)))
		var length:=rng.randf_range(0.25,0.45)
		surface.set_color(Color("90a951").lightened(rng.randf_range(-0.16,0.18)))
		for vertex in [Vector3(0,0,-length),Vector3(-length*0.55,0,0),Vector3(0,0.07,length),Vector3(0,0,-length),Vector3(0,0.07,length),Vector3(length*0.55,0,0)]: surface.add_vertex(center+rotation*vertex)
	surface.generate_normals()
	return surface.commit()
