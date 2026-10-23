extends RefCounted

var texture: Texture2D
var pixels:=0.01
var foot:=0.0
var alpha_valid:=false
var reference_has_alpha:=false
var alpha_bounds:=Rect2i()

func _init() -> void:
	texture=load("res://assets/grape_trellis_v8.png")
	var image:=texture.get_image()
	alpha_bounds=image.get_used_rect()
	alpha_valid=image.detect_alpha()!=Image.ALPHA_NONE
	pixels=4.2/float(alpha_bounds.size.x)
	foot=(alpha_bounds.end.y-image.get_height()*0.5)*pixels
	var reference_texture: Texture2D=load("res://assets/reference_atlas_v8.png")
	var reference:=reference_texture.get_image()
	reference_has_alpha=reference.detect_alpha()!=Image.ALPHA_NONE

func decorate(root: Node3D,theme: String) -> void:
	entrance(root)
	if theme!="wine": return
	for node in root.get_children():
		if node is MultiMeshInstance3D and node.get_script()!=null and node.instance_colors.size()==node.placements.size():
			var kept: Array[Transform3D]=[]
			var colors:=PackedColorArray()
			for i in range(node.placements.size()):
				var p: Vector3=node.placements[i].origin
				if p.x>=-69 and p.x<=-28 and p.z>=-56 and p.z<=-38 and p.y<2.5: continue
				kept.append(node.placements[i])
				colors.append(node.instance_colors[i])
			node.placements=kept
			node.instance_colors=colors
			node._ready()
		if node is MeshInstance3D:
			var p: Vector3=node.position
			if p.x>=-69 and p.x<=-28 and p.z>=-56 and p.z<=-38 and p.y>0.3 and p.y<2.5:
				if node.mesh is CylinderMesh or (node.mesh is BoxMesh and node.mesh.size.x<0.3): node.hide()
	var vines:=Node3D.new()
	vines.name="PixelVineyardV8"
	root.add_child(vines)
	for row in range(8):
		for col in range(9):
			var sprite:=Sprite3D.new()
			sprite.texture=texture
			sprite.pixel_size=pixels
			sprite.position=Vector3(-66.3+col*4.3,foot,-55+row*2.2)
			sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
			sprite.alpha_scissor_threshold=0.3
			sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			sprite.shaded=true
			sprite.double_sided=true
			vines.add_child(sprite)

func entrance(root: Node3D) -> void:
	var material:=ShaderMaterial.new()
	material.shader=load("res://oak_door_v8.gdshader")
	for node in root.get_children():
		if node is MeshInstance3D and node.mesh is BoxMesh and node.mesh.size.is_equal_approx(Vector3(4,3.6,0.2)):
			node.material_override=material
	var fittings:=Node3D.new()
	fittings.name="CellarDoorV8"
	root.add_child(fittings)
	var iron:=StandardMaterial3D.new()
	iron.albedo_color=Color("30332b")
	iron.metallic=0.55
	iron.roughness=0.6
	for side in [-1.0,1.0]:
		for y in [0.8,2.7]:
			var node:=MeshInstance3D.new()
			var mesh:=BoxMesh.new()
			mesh.size=Vector3(1.7,0.13,0.1)
			node.mesh=mesh
			node.position=Vector3(-24+side*1, y,-26.04)
			node.material_override=iron
			fittings.add_child(node)
		var ring:=MeshInstance3D.new()
		var torus:=TorusMesh.new()
		torus.inner_radius=0.11
		torus.outer_radius=0.16
		torus.rings=12
		torus.ring_segments=5
		ring.mesh=torus
		ring.position=Vector3(-24+side*0.35,1.65,-25.96)
		ring.rotation.x=PI/2
		ring.material_override=iron
		fittings.add_child(ring)

func save_logic() -> void:
	FileAccess.open("res://vineyard_logic.json",FileAccess.WRITE).store_string(JSON.stringify({"version":8,"source":"user supplied atlas as style reference; generated isolated trellis asset","reference_has_alpha":reference_has_alpha,"generated_alpha_valid":alpha_valid,"asset":"assets/grape_trellis_v8.png","width_m":4.2,"visible_height_m":alpha_bounds.size.y*pixels,"rows":8,"columns":9,"spacing_xz_m":[4.3,2.2],"origin_xz":[-66.3,-55],"orientation":"fixed vertical X/Y plane; no billboard rotation","collision":"decorative vineyard; unchanged road navigation","alpha_bounds_px":[alpha_bounds.position.x,alpha_bounds.position.y,alpha_bounds.size.x,alpha_bounds.size.y]},"\t"))
