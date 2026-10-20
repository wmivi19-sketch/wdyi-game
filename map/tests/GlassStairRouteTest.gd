extends "res://tests/ReferenceWellTest.gd"
func check(ok: bool,label: String) -> void:
    super.check(ok,label)
    if label=="twelve sections reach L2":
        super.check(game.glass_broken.has("GL1") and game.glass_broken.has("GL2"),"actual continuous stair walk automatically shatters both transit platforms")
