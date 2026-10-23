extends RefCounted

var t: Node3D
var rng := RandomNumberGenerator.new()
var iron: Material
var stone: Material
var timber: Material
var leaf_mesh: SphereMesh
var leaves: Array[Transform3D] = []
var leaf_colors: Array[Color] = []

func _init(town: Node3D) -> void:
	t=town
	rng.seed=20261022
	iron=t.mat("detail_iron",Color("242c29"))
	stone=t.mat("detail_stone",Color("9c927f"))
	timber=t.mat("detail_wood",Color("5d4630"))

func beam(a: Vector3,b: Vector3,r: float,m: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius=r
	mesh.bottom_radius=r
	mesh.height=a.distance_to(b)
	mesh.radial_segments=6
	node.mesh=mesh
	node.material_override=m
	node.position=(a+b)*0.5
	var direction := (b-a).normalized()
	var right := direction.cross(Vector3.FORWARD).normalized()
	if right.length()<0.1: right=direction.cross(Vector3.RIGHT).normalized()
	node.basis=Basis(right,direction,right.cross(direction).normalized())
	t.add_child(node)

func arch(center: Vector3,r: float,thick: float) -> void:
	for i in range(13):
		var angle := float(i)/12.0*PI
		var p:=center+Vector3(cos(angle)*r,sin(angle)*r,0)
		var block: MeshInstance3D=t.box(p,Vector3(thick,r*0.26,0.3),stone)
		block.rotation.z=angle

func signboard(text: String,p: Vector3,w: float) -> void:
	t.box(p,Vector3(w,0.75,0.22),t.mat("sign",Color("1e3b31")))
	for y in [-0.38,0.38]: t.box(p+Vector3(0,y,0.13),Vector3(w,0.055,0.06),stone)
	var label := Label3D.new()
	label.text=text
	label.font_size=48
	label.pixel_size=0.008
	label.modulate=Color("e9ce91")
	label.outline_size=0
	label.position=p+Vector3(0,0,0.15)
	t.add_child(label)

func architecture() -> void:
	for b in t.footprints:
		var x: float=b.x
		var z: float=b.z
		var w: float=b.width
		var d: float=b.depth
		var h: float=b.height
		var front:=z+d/2
		# Narrow quoins, cornices and drainpipes articulate the brick mass.
		for xx in [x-w/2+0.12,x+w/2-0.12]:
			for yy in range(int(h/0.55)):
				t.box(Vector3(xx,0.3+yy*0.55,front+0.1),Vector3(0.42 if yy%2 else 0.65,0.24,0.22),stone)
		for xx in [x-w/2+0.4,x+w/2-0.4]: beam(Vector3(xx,0.3,front+0.25),Vector3(xx,h,front+0.25),0.055,iron)
		for yy in [h-0.4,h,h+0.14]: t.box(Vector3(x,yy,z),Vector3(w+0.55,0.12,d+0.55),stone)
		beam(Vector3(x-w/2-0.5,h+3,z),Vector3(x+w/2+0.5,h+3,z),0.13,iron)
		for xx in [x-w*0.28,x+w*0.28]:
			# Dormer windows on the visible roof face.
			t.box(Vector3(xx,h+1.7,z+d*0.28),Vector3(1.65,1.6,1.2),t.mat("dormer",Color("433c32")))
			t.box(Vector3(xx,h+1.7,z+d*0.28+0.62),Vector3(0.85,1.05,0.06),t.mat("window_dim",Color("b48c4c"),false,true))
			for side in [-1.0,1.0]:
				var cap: MeshInstance3D=t.box(Vector3(xx+side*0.45,h+2.7,z+d*0.28),Vector3(1.15,0.13,1.5),t.mat("roof",Color("293641"),true))
				cap.rotation.z=-side*0.55
		for wx in range(int(w/2.8)):
			var xx:=x-w/2+1.5+wx*2.8
			for wy in range(int(h/3)):
				var yy:=1.8+wy*3
				t.box(Vector3(xx,yy-0.9,front+0.23),Vector3(1.45,0.13,0.45),stone)
				if wy>0:
					arch(Vector3(xx,yy+0.72,front+0.16),0.57,0.17)
		if b.id=="winery":
			# Enlarged cellar entrance and unloading canopy.
			t.box(Vector3(x,1.8,front+0.26),Vector3(4.0,3.6,0.2),timber)
			arch(Vector3(x,3.2,front+0.4),2.0,0.42)
			for side in [-1.0,1.0]: t.box(Vector3(x+side*2.1,1.6,front+0.35),Vector3(0.45,3.2,0.6),stone)
			for xx in range(-3,4): t.box(Vector3(x+xx*0.52,1.7,front+0.39),Vector3(0.04,3.3,0.1),iron)
			signboard("ELANSER  /  CELLARS" if t.district_type=="wine" else ("GRAIN  /  FLOUR MILL" if t.district_type=="wheat" else "FLAX  /  WEAVING HOUSE"),Vector3(x,6.1,front+0.3),10)
			canopy(Vector3(x-6,0,front+3),7,4)
		elif b.id=="export_warehouse":
			t.box(Vector3(x,2.2,front+0.2),Vector3(5.3,4.4,0.22),t.mat("shutter",Color("405443")))
			for yy in [0.7,3.5]: t.box(Vector3(x,yy,front+0.4),Vector3(5.4,0.13,0.12),iron)
			signboard("WINE  EXPORT  DEPOT" if t.district_type=="wine" else ("GRAIN  STORAGE" if t.district_type=="wheat" else "LINEN  EXPORT  DEPOT"),Vector3(x,5.2,front+0.3),13)
			canopy(Vector3(x,0,front+3),12,4.5)
		elif b.id=="wine_merchant":
			shop(x,z,w,d,h)
		elif str(b.id).begins_with("row_"):
			canopy(Vector3(x,0,front+1),w-1,1.5)
			for xx in [-2.8,2.8]: flowerbox(Vector3(x+xx,0.4,front+0.6))
		# Sparse ivy clusters, not flat green blocks.
		for j in range(16):
			foliage(Vector3(x-w/2+0.4+rng.randf_range(-0.5,0.5),rng.randf_range(0.5,h*0.7),front+0.4),rng.randf_range(0.22,0.42))

func canopy(p: Vector3,w: float,d: float) -> void:
	var roof: MeshInstance3D=t.box(p+Vector3(0,3.2,0),Vector3(w,0.15,d),t.mat("canopy",Color("33463d")))
	roof.rotation.x=0.1
	for xx in [-w/2+0.15,w/2-0.15]:
		beam(p+Vector3(xx,0,-d/2),p+Vector3(xx,3.2,-d/2),0.08,iron)
		beam(p+Vector3(xx,0,d/2),p+Vector3(xx,3.2,d/2),0.08,iron)
	for i in range(int(w*2)):
		t.box(p+Vector3(-w/2+i*0.5,3.05,d/2),Vector3(0.23,0.3,0.12),stone)

func shop(x: float,z: float,w: float,d: float,h: float) -> void:
	var front:=z+d/2
	var green: Material=t.mat("shop_green",Color("244638"))
	for xx in [x-w/2+0.5,x-2,x+2,x+w/2-0.5]:
		t.box(Vector3(xx,1.65,front+0.35),Vector3(0.38,3.3,0.45),green)
	for xx in [x-3.8,x+3.8]:
		t.box(Vector3(xx,1.6,front+0.21),Vector3(2.7,2.3,0.15),t.mat("shopglass",Color("bc873e"),false,true))
		for y in [0.7,1.4,2.1]: t.box(Vector3(xx,y,front+0.35),Vector3(2.7,0.08,0.2),timber)
		for k in range(5):
			for y in [0.95,1.65]: t.cylinder(Vector3(xx-1+k*0.5,y,front+0.47),0.07,0.35,green)
	canopy(Vector3(x,0,front+0.9),w+0.3,1.5)
	signboard("VINTNERS  &  MERCHANTS" if t.district_type=="wine" else ("BAKERS  &  PROVISIONS" if t.district_type=="wheat" else "LINEN  &  DRAPERY"),Vector3(x,3.85,front+0.25),w)
	# Iron balcony at the central upper window.
	t.box(Vector3(x,5.0,front+0.6),Vector3(3.5,0.16,1.3),stone)
	for i in range(12): beam(Vector3(x-1.65+i*0.3,5,front+1.1),Vector3(x-1.65+i*0.3,5.85,front+1.1),0.025,iron)
	beam(Vector3(x-1.8,5.85,front+1.1),Vector3(x+1.8,5.85,front+1.1),0.06,iron)
	for xx in [x-w/2,x+w/2]:
		for y in [3.6,6.6,h]: t.box(Vector3(xx,y,front+0.15),Vector3(0.65,0.22,0.6),stone)

func foliage(p: Vector3,r: float) -> void:
	var transform:=Transform3D(Basis.IDENTITY.scaled(Vector3(r,r*0.8,r)),p)
	leaves.append(transform)
	leaf_colors.append(Color("3e562d").lightened(rng.randf_range(-0.12,0.13)))

func flowerbox(p: Vector3) -> void:
	t.box(p,Vector3(1.8,0.65,0.6),timber)
	for i in range(5): foliage(p+Vector3(-0.7+i*0.35,0.4,0),0.38)

func garden() -> void:
	# Break up the ground with planting beds and clustered trees.
	for p in [Vector3(-44,0,-30),Vector3(-4,0,-29),Vector3(2,0,17),Vector3(23,0,29),Vector3(-57,0,12),Vector3(50,0,-24),Vector3(-40,0,35),Vector3(-23,0,35),Vector3(43,0,38),Vector3(61,0,37)]:
		t.cylinder(p+Vector3(0,0.06,0),2.7,0.1,t.mat("soil",Color("3e3529")))
		beam(p,p+Vector3(0,6,0),0.18,timber)
		for j in range(25):
			var offset:=Vector3(rng.randf_range(-1.8,1.8),rng.randf_range(3.0,7),rng.randf_range(-1.8,1.8))
			foliage(p+offset,rng.randf_range(0.55,1.1))
	if t.district_type!="wine":
		crop_field()
		flush_foliage()
		return
	for row in range(8):
		var zz: float=-55+row*2.2
		t.box(Vector3(-49,0.02,zz),Vector3(39,0.035,1.05),t.mat("soil",Color("3e3529")))
		beam(Vector3(-68,1.4,zz),Vector3(-29,1.4,zz),0.022,iron)
		for col in range(17):
			var p:=Vector3(-67+col*2.2,1.4,zz)
			for j in range(4): foliage(p+Vector3(rng.randf_range(-0.7,0.7),rng.randf_range(-0.2,0.5),rng.randf_range(-0.3,0.3)),0.48)
			if col%2==0:
				t.cylinder(p-Vector3(0,0.6,0),0.045,2,timber)
				t.box(p+Vector3(0.3,-0.4,0.35),Vector3(0.19,0.32,0.18),t.mat("grape_detail",Color("342637")))
	flush_foliage()

func flush_foliage() -> void:
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_colors=true
	var mesh:=SphereMesh.new()
	mesh.radius=1
	mesh.height=2
	mesh.radial_segments=7
	mesh.rings=4
	mm.mesh=mesh
	mm.instance_count=leaves.size()
	for i in range(leaves.size()):
		mm.set_instance_transform(i,leaves[i])
		mm.set_instance_color(i,leaf_colors[i])
	var node:=MultiMeshInstance3D.new()
	node.multimesh=mm
	var m:=StandardMaterial3D.new()
	m.vertex_color_use_as_albedo=true
	m.roughness=0.9
	node.material_override=m
	node.set_script(load("res://restore_instances.gd"))
	node.placements=leaves
	node.instance_colors=PackedColorArray(leaf_colors)
	t.add_child(node)

func cart(p: Vector3) -> void:
	t.box(p+Vector3(0,0.9,0),Vector3(2.5,0.22,4.5),timber,true)
	for side in [-1.0,1.0]:
		for y in [1.25,1.55]: t.box(p+Vector3(side*1.2,y,0),Vector3(0.15,0.18,4.6),timber)
		for zz in [-1.45,1.45]:
			var wheel:=MeshInstance3D.new()
			var torus:=TorusMesh.new()
			torus.inner_radius=0.54
			torus.outer_radius=0.69
			torus.rings=16
			torus.ring_segments=6
			wheel.mesh=torus
			wheel.material_override=iron
			wheel.position=p+Vector3(side*1.35,0.7,zz)
			wheel.rotation.z=PI/2
			t.add_child(wheel)
			for a in range(8):
				var angle:=a*PI/4
				beam(wheel.position,wheel.position+Vector3(0,cos(angle)*0.58,sin(angle)*0.58),0.035,timber)
	for xx in [-0.55,0.55]:
		for zz in [-1.2,0,1.2]: t.cargo(p+Vector3(xx,1,zz))
	for xx in [-0.8,0.8]: beam(p+Vector3(xx,0.8,-2),p+Vector3(xx,0.6,-4.3),0.06,timber)

func props() -> void:
	cart(Vector3(-15,0,-16))
	cart(Vector3(40,0,-10))
	for p in [Vector3(-33,0,-21),Vector3(-29,0,-19),Vector3(25,0,-12)]:
		for level in range(2):
			var pp: Vector3=p+Vector3(0,0.55+level*1.05,0)
			t.box(pp,Vector3(1.6,1,1.4),t.mat("crate",Color("796143")),true)
			for xx in [-0.65,0.65]: t.box(pp+Vector3(xx,0,0.73),Vector3(0.12,1,0.08),timber)
	# Brick-edged flower beds, benches and drain grilles remain outside navigation roads.
	for x in [-48,-20,3,30,57]:
		flowerbox(Vector3(x,0.4,6.8))
		var p:=Vector3(x+3,0,6.9)
		for dz in [-0.3,0,0.3]: t.box(p+Vector3(0,0.6,dz),Vector3(1.8,0.1,0.16),timber)
		for xx in [-0.65,0.65]: beam(p+Vector3(xx,0,0),p+Vector3(xx,0.65,0),0.06,iron)
		for j in range(7): t.box(Vector3(x+j*0.1,0.06,3.85),Vector3(0.04,0.025,0.4),iron)
	for z in [-4.1,4.1]:
		for x in range(-78,80,2): t.box(Vector3(x,0.1,z),Vector3(1.97,0.2,0.15),stone)

func build() -> void:
	architecture()
	props()
	garden()
	if t.district_type=="wheat": mill()
	if t.district_type=="flax": textile_yard()

func crop_field() -> void:
	var wheat: bool=t.district_type=="wheat"
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_colors=true
	var tuft:=PrismMesh.new()
	tuft.size=Vector3(0.18,0.9 if wheat else 0.65,0.18)
	mm.mesh=tuft
	mm.instance_count=30*75
	var placements: Array[Transform3D]=[]
	var colors:=PackedColorArray()
	for row in range(30):
		for col in range(75):
			var p:=Vector3(-68+col*0.53+rng.randf_range(-0.12,0.12),0.48 if wheat else 0.36,-56+row*0.55)
			var transform:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU),p)
			var tint: Color=(Color("b89a4b") if wheat else Color("4c7968")).lightened(rng.randf_range(-0.12,0.12))
			placements.append(transform)
			colors.append(tint)
			mm.set_instance_transform(row*75+col,transform)
			mm.set_instance_color(row*75+col,tint)
	var crops:=MultiMeshInstance3D.new()
	crops.multimesh=mm
	crops.name="WheatField" if wheat else "FlaxField"
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	crops.material_override=material
	crops.set_script(load("res://restore_instances.gd"))
	crops.placements=placements
	crops.instance_colors=colors
	t.add_child(crops)
	if not wheat:
		var flowers:=MultiMesh.new()
		flowers.transform_format=MultiMesh.TRANSFORM_3D
		var flower:=SphereMesh.new()
		flower.radius=0.06
		flower.height=0.08
		flower.radial_segments=5
		flower.rings=3
		flowers.mesh=flower
		flowers.instance_count=600
		var flower_positions: Array[Transform3D]=[]
		for j in range(600):
			var transform:=Transform3D(Basis.IDENTITY,Vector3(rng.randf_range(-68,-28),0.72,rng.randf_range(-56,-40)))
			flowers.set_instance_transform(j,transform)
			flower_positions.append(transform)
		var blooms:=MultiMeshInstance3D.new()
		blooms.multimesh=flowers
		blooms.material_override=t.mat("flax_blue",Color("839fd1"))
		blooms.set_script(load("res://restore_instances.gd"))
		blooms.placements=flower_positions
		t.add_child(blooms)

func mill() -> void:
	var center:=Vector3(-24,15,-25.5)
	var tower:=MeshInstance3D.new()
	var c:=CylinderMesh.new()
	c.top_radius=1.5
	c.bottom_radius=2.5
	c.height=6
	c.radial_segments=10
	tower.mesh=c
	tower.material_override=t.mat("mill_stone",Color("8f8973"),true)
	tower.position=Vector3(-24,11,-32)
	t.add_child(tower)
	var sails:=Node3D.new()
	sails.name="MillSails"
	sails.position=center
	sails.add_to_group("mill_sails",true)
	t.add_child(sails)
	for i in range(4):
		var arm:=Node3D.new()
		arm.rotation.z=i*PI/2+0.2
		sails.add_child(arm)
		var blade:=MeshInstance3D.new()
		var mesh:=BoxMesh.new()
		mesh.size=Vector3(1.4,4.4,0.12)
		blade.mesh=mesh
		blade.material_override=t.mat("sail_canvas",Color("c8ba8b"))
		blade.position=Vector3(0.5,3.2,0)
		arm.add_child(blade)
		for j in range(9):
			var rib:=MeshInstance3D.new()
			var rb:=BoxMesh.new()
			rb.size=Vector3(1.55,0.06,0.16)
			rib.mesh=rb
			rib.material_override=timber
			rib.position=Vector3(0.5,1.1+j*0.5,0.1)
			arm.add_child(rib)

func textile_yard() -> void:
	for i in range(4):
		var x: float=-40+i*4
		beam(Vector3(x,0,-15),Vector3(x,3.4,-15),0.09,timber)
		beam(Vector3(x,0,-20),Vector3(x,3.4,-20),0.09,timber)
		beam(Vector3(x,3.3,-15),Vector3(x,3.3,-20),0.04,iron)
		for j in range(3):
			t.box(Vector3(x,2.2,-16-j*1.3),Vector3(0.04,2,1.0),t.mat("cloth_%s"%j,Color("d4c8ab") if j%2 else Color("6a8590")))
	for i in range(3): t.cylinder(Vector3(-29+i*5,11.5,-36),0.6,9,t.mat("brick",Color("974f35"),true))
