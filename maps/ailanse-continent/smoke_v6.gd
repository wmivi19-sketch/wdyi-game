extends Node3D

var time:=0.0
var particles: Array[MeshInstance3D]=[]

func _ready() -> void:
	for i in range(7):
		var puff:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		quad.size=Vector2.ONE
		puff.mesh=quad
		var material:=ShaderMaterial.new()
		material.shader=load("res://smoke_v6.gdshader")
		material.set_shader_parameter("phase",float(i)*1.7)
		puff.material_override=material
		puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff)
		particles.append(puff)

func _process(delta: float) -> void:
	time+=delta
	var camera:=get_viewport().get_camera_3d()
	if camera==null: return
	for i in range(particles.size()):
		var age:=fmod(time+float(i)*1.4,9.8)
		var puff:=particles[i]
		puff.position=Vector3(age*0.35,age*0.68,age*0.13)
		puff.look_at(camera.global_position,Vector3.UP)
		puff.scale=Vector3.ONE*(0.5+age*0.39)
		puff.material_override.set_shader_parameter("opacity",0.15*sin(age/9.8*PI))
