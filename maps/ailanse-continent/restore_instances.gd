@tool
extends MultiMeshInstance3D

# Persist CPU-side transforms: the headless renderer does not retain GPU buffers.
@export var placements: Array[Transform3D]=[]
@export var instance_colors: PackedColorArray=PackedColorArray()

func _ready() -> void:
	if multimesh==null or placements.is_empty(): return
	var restored:=MultiMesh.new()
	restored.transform_format=MultiMesh.TRANSFORM_3D
	restored.use_colors=multimesh.use_colors
	restored.mesh=multimesh.mesh
	multimesh=restored
	multimesh.instance_count=placements.size()
	var bounds:=AABB(placements[0].origin-Vector3(2,2,2),Vector3(4,4,4))
	for i in range(placements.size()):
		multimesh.set_instance_transform(i,placements[i])
		if multimesh.use_colors and i<instance_colors.size(): multimesh.set_instance_color(i,instance_colors[i])
		bounds=bounds.expand(placements[i].origin-Vector3(2,2,2))
		bounds=bounds.expand(placements[i].origin+Vector3(2,2,2))
	multimesh.custom_aabb=bounds
