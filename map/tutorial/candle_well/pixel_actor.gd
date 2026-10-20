extends Node2D
## Integer pixel silhouettes; no smooth shapes or antialiased outlines.
var player: CharacterBody2D
var facing := Vector2(0,1)
var phase: float = 0.0
var elevation: float = 0.0

func _process(delta: float) -> void:
    if player.velocity.length()>1:
        facing = Vector2(player.velocity.x-player.velocity.y,(player.velocity.x+player.velocity.y)*0.5).normalized()
        phase += delta*11.0
    else:
        phase = 0.0
    queue_redraw()

func pixel_rect(x: int,y: int,w: int,h: int,c: String) -> void:
    draw_rect(Rect2(x,y,w,h),Color(c))

func _draw() -> void:
    draw_set_transform(Vector2(0,-elevation))
    var stride: int = 2 if sin(phase)>0.0 and phase>0 else 0
    # Feet are the transform/sort anchor. Cloak, shoulders, helmet are above it.
    pixel_rect(-6,-3-stride,4,3,"252a30")
    pixel_rect(2,-3+stride,4,3,"252a30")
    pixel_rect(-7,-16,14,11,"343e49")
    pixel_rect(-9,-13,18,7,"45515c")
    pixel_rect(-7,-7,14,3,"394550")
    pixel_rect(-4,-15,3,10,"6b7475")
    pixel_rect(2,-14,3,10,"56636b")
    pixel_rect(-6,-24,12,9,"777f7b")
    pixel_rect(-4,-27,8,3,"a2a395")
    pixel_rect(-7,-22,2,5,"525f65")
    pixel_rect(5,-22,2,5,"525f65")
    var back: bool = facing.y < -0.35
    if back:
        pixel_rect(-4,-23,8,7,"657174")
        pixel_rect(-2,-22,2,11,"8d9389")
    else:
        pixel_rect(-5,-21,10,3,"202e36")
        pixel_rect(-3 if facing.x<0 else 1,-20,2,1,"a5aa94")
        pixel_rect(-2,-17,4,2,"999a87")
    # A sheathed iron blade makes left/right facing distinguishable.
    var side: int = -1 if facing.x<0 else 1
    pixel_rect(8*side-1,-13,2,15,"8a8d7d")
    pixel_rect(6*side-1,-13,6,2,"5f6867")
