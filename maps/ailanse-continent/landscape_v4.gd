extends RefCounted

var world: Node3D
var texture: Texture2D
var ground: ShaderMaterial
var tree_count:=0
var parcels: Array=[]
var tree_pixels:=1.0
var foot_offset:=0.0
var alpha_valid:=false

func _init(host: Node3D) -> void:
	world=host
	texture=load("res://assets/elm_tree_v4.png")
	var image:=texture.get_image()
	var rect:=image.get_used_rect()
	alpha_valid=image.detect_alpha()!=Image.ALPHA_NONE and rect.size.y>0
	tree_pixels=7.0/float(rect.size.y)
	foot_offset=(rect.end.y-image.get_height()*0.5)*tree_pixels
	ground=ShaderMaterial.new()
	ground.shader=load("res://terrain.gdshader")

func tree(parent: Node3D,p: Vector3,scale_factor:=1.0,solid:=true) -> void:
	var sprite:=Sprite3D.new()
	sprite.name="ElmTree"
	sprite.texture=texture
	sprite.pixel_size=tree_pixels*scale_factor
	sprite.position=p+Vector3(0,foot_offset*scale_factor,0)
	sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold=0.3
	sprite.shaded=true
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	sprite.visibility_range_end=230
	parent.add_child(sprite)
	tree_count+=1
	if solid:
		var body:=StaticBody3D.new()
		var shape:=CollisionShape3D.new()
		var cylinder:=CylinderShape3D.new()
		cylinder.radius=0.3*scale_factor
		cylinder.height=3
		shape.shape=cylinder
		body.position=p+Vector3(0,1.5,0)
		body.add_child(shape)
		parent.add_child(body)

func decorate_town(root: Node3D) -> void:
	var spots: Array[Vector3]=[Vector3(-44,0,-30),Vector3(-4,0,-29),Vector3(2,0,17),Vector3(23,0,29),Vector3(-57,0,12),Vector3(50,0,-24),Vector3(-40,0,35),Vector3(-23,0,35),Vector3(43,0,38),Vector3(61,0,37)]
	for node in root.get_children():
		if node is MeshInstance3D and node.mesh is BoxMesh and node.mesh.size.x==160 and node.mesh.size.z==120: node.material_override=ground
		if node is MeshInstance3D and node.mesh is CylinderMesh and absf(node.mesh.height-6.0)<0.01:
			for spot in spots:
				if Vector2(node.position.x-spot.x,node.position.z-spot.z).length()<0.1: node.hide()
		if node is MultiMeshInstance3D and node.get_script()!=null and node.multimesh.mesh is SphereMesh and node.instance_colors.size()==node.placements.size():
			var kept: Array[Transform3D]=[]
			var colors:=PackedColorArray()
			for i in range(node.placements.size()):
				var p: Vector3=node.placements[i].origin
				var canopy:=false
				for spot in spots:
					if p.y>2.5 and Vector2(p.x-spot.x,p.z-spot.z).length()<2.6: canopy=true
				if not canopy:
					kept.append(node.placements[i])
					colors.append(node.instance_colors[i])
			node.placements=kept
			node.instance_colors=colors
			node._ready()
	for spot in spots: tree(root,spot,1.0)

func build() -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=20261022
	# Agricultural parcels leave every road and 160 x 120 m town core clear.
	for z in [-350,-130,50,150,360]:
		for x in [-380,-140,80,350]:
			var kind: String="vine" if z<0 else ("wheat" if x<0 else "flax")
			parcels.append({"center":[x,z],"size":[65,54],"crop":kind})
			world.box(Vector3(x,0.03,z),Vector3(65,0.06,54),world.mat("field_soil",Color("51432d")))
			var mesh:=BoxMesh.new()
			mesh.size=Vector3(0.5,0.85,0.5) if kind!="vine" else Vector3(0.9,1.5,1.3)
			var instances:=MultiMesh.new()
			instances.transform_format=MultiMesh.TRANSFORM_3D
			instances.mesh=mesh
			instances.instance_count=32*24
			for row in range(24):
				for col in range(32): instances.set_instance_transform(row*32+col,Transform3D(Basis.IDENTITY,Vector3(x-30+col*1.9,mesh.size.y/2+0.06,z-24+row*2.1)))
			var field:=MultiMeshInstance3D.new()
			field.multimesh=instances
			field.material_override=world.mat("rural_"+kind,Color("617135") if kind=="vine" else (Color("b09848") if kind=="wheat" else Color("697e9c")))
			world.add_child(field)
			for k in range(5): tree(world,Vector3(x-30+k*15,0,z+31),rng.randf_range(0.8,1.2))
	# Avenue trees stay outside the swept navigation corridor.
	for z in range(-180,200,24):
		for x in [-246,274]: tree(world,Vector3(x,0,z),rng.randf_range(0.8,1.15))
	# Wine export quay, crates, mooring bollards and a small loading crane.
	world.box(Vector3(397,0.08,-270),Vector3(34,0.16,28),world.mat("quay",Color("8a8472")))
	for x in [385,391,397]:
		for z in [-279,-274]: world.box(Vector3(x,0.8,z),Vector3(2,1.6,2),world.mat("cargo_wood",Color("785535")),true)
	world.box(Vector3(408,5,-275),Vector3(0.6,10,0.6),world.mat("crane_iron",Color("323638")),true)
	world.box(Vector3(412,10,-275),Vector3(9,0.4,0.4),world.mat("crane_iron",Color("323638")))
	world.box(Vector3(416,6.5,-275),Vector3(0.08,7,0.08),world.mat("crane_iron",Color("323638")))
	for z in [-282,-270,-258]: world.cylinder(Vector3(414,0.5,z),0.3,1.0,world.mat("crane_iron",Color("323638")))
	hull()
	world.box(Vector3(432,2,-270),Vector3(7,0.2,21),world.mat("boat_deck",Color("927849")))
	world.box(Vector3(432,4,-276),Vector3(5,4,5),world.mat("boat_cabin",Color("775b40")))
	world.cylinder(Vector3(432,9,-268),0.16,17,world.mat("boat_mast",Color("513c27")))
	for z in range(-279,-259):
		world.box(Vector3(432,2.12,z),Vector3(6.9,0.04,0.06),world.mat("deck_seams",Color("49382b")))
	for x in [428.5,435.5]:
		world.box(Vector3(x,2.6,-270),Vector3(0.16,0.18,20),world.mat("boat_hull",Color("49382b")))
		for z in range(-279,-259,3): world.cylinder(Vector3(x,2.35,z),0.07,0.6,world.mat("boat_hull",Color("49382b")))
	for x in [430.5,432,433.5]: world.box(Vector3(x,4.2,-273.45),Vector3(0.8,1,0.05),world.mat("boat_windows",Color("bd9854"),false,true))
	world.box(Vector3(432,6.1,-276),Vector3(5.5,0.25,5.5),world.mat("boat_roof",Color("394345")))
	for x in [385,391,397]:
		for z in [-279,-274]:
			for offset in [-0.7,0.7]:
				world.box(Vector3(x+offset,0.8,z),Vector3(0.1,1.65,2.04),world.mat("crate_straps",Color("39372e")))
	var brace: MeshInstance3D=world.box(Vector3(410,8,-275),Vector3(0.22,5.6,0.22),world.mat("crane_iron",Color("323638")))
	brace.rotation.z=-PI/4
	world.box(Vector3(416,3.2,-275),Vector3(0.7,0.15,0.15),world.mat("crane_iron",Color("323638")))
	for x in [385,397,410]: world.lamp(x,-284,true)
	for x in range(380,417): world.box(Vector3(x,0.115,-250),Vector3(0.06,0.03,6),world.mat("deck_seams",Color("49382b")))

func hull() -> void:
	var outline: Array[Vector2]=[Vector2(-3.6,-10.5),Vector2(3.6,-10.5),Vector2(4,-5),Vector2(4,7),Vector2(2.8,11),Vector2(0,14),Vector2(-2.8,11),Vector2(-4,7),Vector2(-4,-5)]
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(outline.size()):
		var a:=outline[i]
		var b:=outline[(i+1)%outline.size()]
		var top_a:=Vector3(a.x,2,a.y)
		var top_b:=Vector3(b.x,2,b.y)
		var low_a:=Vector3(a.x*0.75,0.2,a.y*0.9)
		var low_b:=Vector3(b.x*0.75,0.2,b.y*0.9)
		for v in [top_a,low_a,top_b,top_b,low_a,low_b,Vector3(0,2,0),top_a,top_b]: surface.add_vertex(v)
	surface.generate_normals()
	var node:=MeshInstance3D.new()
	node.mesh=surface.commit()
	node.position=Vector3(432,0,-270)
	node.material_override=world.mat("boat_hull",Color("49382b"))
	world.add_child(node)
