extends Node2D
## Pure 2D pixel projection. Physics remains on the original 16px ground grid.
var game
var avatar: Node2D
var walls: Array[Node2D] = []
var dynamic_root: Node2D
var stair_samples: Array = []
const SPIRAL_STEPS: int = 32
const SPIRAL_INNER: float = 48.0
const SPIRAL_OUTER: float = 104.0
const SPIRAL_RISE: float = 64.0
var spiral_root: Node2D

func project(p: Vector2) -> Vector2:
    return Vector2(roundf(p.x-p.y)+1024.0,roundf((p.x+p.y)*0.5))

func polygon(parent: Node2D, points: Array, color: String) -> Polygon2D:
    var node := Polygon2D.new()
    node.polygon = PackedVector2Array(points)
    node.color = Color(color)
    node.antialiased = false
    parent.add_child(node)
    return node

func line(parent: Node2D, points: Array, color: String, width: float = 1.0) -> void:
    var node := Line2D.new()
    node.points = PackedVector2Array(points)
    node.default_color = Color(color)
    node.width = width
    node.antialiased = false
    parent.add_child(node)

func diamond(parent: Node2D, x: float, y: float, w: float, h: float, c: String) -> void:
    polygon(parent,[Vector2(x,y-h),Vector2(x+w,y),Vector2(x,y+h),Vector2(x-w,y)],c)

func prism(parent: Node2D, w: float, depth: float, height: float, top: String, left: String, right: String) -> void:
    polygon(parent,[Vector2(-w,0),Vector2(0,depth),Vector2(0,depth-height),Vector2(-w,-height)],left)
    polygon(parent,[Vector2(0,depth),Vector2(w,0),Vector2(w,-height),Vector2(0,depth-height)],right)
    polygon(parent,[Vector2(0,-depth-height),Vector2(w,-height),Vector2(0,depth-height),Vector2(-w,-height)],top)

func build() -> void:
    y_sort_enabled = true
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var floor_set: Dictionary = {}
    for c in game.data.levels[game.current_level].walkable:
        floor_set[Vector2i(int(c[0]),int(c[1]))] = true
    var floors := Node2D.new()
    floors.z_index = -20
    add_child(floors)
    for c in game.data.levels[game.current_level].walkable:
        var x: int = int(c[0])
        var y: int = int(c[1])
        var p := project(Vector2(x*16+8,y*16+8))
        var tile := Node2D.new()
        tile.position = p
        floors.add_child(tile)
        var colors: Array = ["545b59","4b5353","5c5f56","505654","5c625a"]
        diamond(tile,0,0,16,8,colors[posmod(x*17+y*31,colors.size())])
        line(tile,[Vector2(-16,0),Vector2(0,8),Vector2(16,0)],"1b2225")
        if posmod(x*13+y*19,7)==0:
            line(tile,[Vector2(-5,-2),Vector2(1,0),Vector2(5,-1)],"50534a")
        if posmod(x*7+y*23,23)==0:
            line(tile,[Vector2(-9,0),Vector2(-3,-1),Vector2(0,2),Vector2(7,3)],"171e22")
        # Visible platform rim: material side faces, not a fake cast shadow.
        if not floor_set.has(Vector2i(x+1,y)):
            polygon(tile,[Vector2(16,0),Vector2(0,8),Vector2(0,27),Vector2(16,19)],"1c2428")
            line(tile,[Vector2(3,15),Vector2(12,10)],"303739")
        if not floor_set.has(Vector2i(x,y+1)):
            polygon(tile,[Vector2(-16,0),Vector2(0,8),Vector2(0,27),Vector2(-16,19)],"252c2e")
    # Freestanding rough masonry on the boundary. Sorted by feet, so actors pass behind it.
    for c in game.data.levels[game.current_level].solid:
        var x: int = int(c[0])
        var y: int = int(c[1])
        var boundary: bool = false
        for delta in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
            if floor_set.has(Vector2i(x,y)+delta):
                boundary = true
        if not boundary:
            continue
        # Shaft gets a shorter, thick octagonal parapet.
        var core: bool = x>=28 and x<36 and y>=12 and y<20
        if core:
            continue # Replaced by the continuous stone spindle below.
        var wall := Node2D.new()
        wall.position = project(Vector2(x*16+8,y*16+8))
        wall.set_meta("foot",wall.position)
        var height: int = (19 if core else 36)+posmod(x*11+y*7,5)
        add_child(wall)
        prism(wall,16,8,height,"72776b","4b5551","3b4749")
        # Uneven cap chips, staggered masonry courses and vertical gouges.
        polygon(wall,[Vector2(-12,-height),Vector2(-6,-height-4),Vector2(-2,-height-2),Vector2(-6,-height+1)],"73766a")
        polygon(wall,[Vector2(9,-height-2),Vector2(13,-height),Vector2(10,-height+3),Vector2(6,-height+2)],"2e393d")
        for row in range(1,3):
            var yy: float = -height+row*11
            line(wall,[Vector2(-15,yy),Vector2(0,yy+8),Vector2(15,yy)],"192329")
            line(wall,[Vector2(-8,yy+4),Vector2(-8,yy+13)],"252f33")
            line(wall,[Vector2(7,yy+4),Vector2(7,yy+12)],"172329")
        line(wall,[Vector2(-11,-height+4),Vector2(-7,-height+9),Vector2(-9,-height+14)],"242f34")
        walls.append(wall)
        var occluder := LightOccluder2D.new()
        var shape := OccluderPolygon2D.new()
        shape.polygon = PackedVector2Array([Vector2(0,-8-height),Vector2(16,-height),Vector2(16,0),Vector2(0,8),Vector2(-16,0),Vector2(-16,-height)])
        occluder.occluder = shape
        wall.add_child(occluder)
    build_spiral()
    dynamic_root = Node2D.new()
    dynamic_root.y_sort_enabled = true
    add_child(dynamic_root)
    avatar = Node2D.new()
    avatar.set_script(load("res://tutorial/candle_well/pixel_actor.gd"))
    avatar.player = game.player
    add_child(avatar)
    sync_objects()

func polar(radius: float, angle: float) -> Vector2:
    return Vector2(512,512)+Vector2(cos(angle),sin(angle))*radius

func build_spiral() -> void:
    # A complete 360-degree helical ribbon, built from annular wedge treads.
    # Each tread rises 2px: 32 treads / 64px rise, with an east-side seam/landing.
    spiral_root = Node2D.new()
    spiral_root.name = "SpiralStair"
    spiral_root.y_sort_enabled = true
    add_child(spiral_root)
    for step in range(SPIRAL_STEPS):
        var a: float = float(step)*TAU/SPIRAL_STEPS
        var b: float = float(step+1)*TAU/SPIRAL_STEPS
        var mid: float = (a+b)*0.5
        var ground := polar((SPIRAL_INNER+SPIRAL_OUTER)*0.5,mid)
        var elevation: float = float(step+1)*SPIRAL_RISE/SPIRAL_STEPS
        stair_samples.append({"ground":ground,"height":elevation,"angle":mid})
        var tread := Node2D.new()
        tread.name = "Tread%02d" % step
        tread.position = project(ground)
        spiral_root.add_child(tread)
        var verts: Array = []
        for point in [polar(SPIRAL_INNER,a),polar(SPIRAL_OUTER,a),polar(SPIRAL_OUTER,b),polar(SPIRAL_INNER,b)]:
            verts.append(project(point)-tread.position-Vector2(0,elevation))
        # Outer fascia and radial riser give each step actual visible thickness.
        polygon(tread,[verts[1],verts[2],verts[2]+Vector2(0,8),verts[1]+Vector2(0,8)],"303b3d")
        polygon(tread,[verts[2],verts[3],verts[3]+Vector2(0,8),verts[2]+Vector2(0,8)],"424b46")
        polygon(tread,verts,"656b60" if step%3 else "717363")
        line(tread,[verts[1],verts[2]],"8a8b76",1)
        line(tread,[verts[2],verts[3]],"222e33",1)
        # Chipped noses and hairline cracks, without opening a collision hole.
        if step%4==1:
            var chip: Vector2 = (verts[1]+verts[2])*0.5
            polygon(tread,[chip+Vector2(-4,-2),chip+Vector2(2,1),chip+Vector2(5,-1)],"29383c")
        if step%3==0:
            line(tread,[verts[3].lerp(verts[2],0.25),verts[3].lerp(verts[2],0.5)+Vector2(-2,1),verts[3].lerp(verts[2],0.65)],"404d4b")
        # Short stone-to-spindle brackets support the inner edge of the helix.
        if step%4==0:
            var support: Vector2 = project(polar(33,mid))-tread.position
            polygon(tread,[verts[0],verts[3],support-Vector2(0,maxf(0,elevation-14))],"354145")
        # Weathered iron handrail; leave east/west landing openings unblocked.
        if absf(sin(mid))>0.27 and absf(wrapf(mid-PI*0.5,-PI,PI))>0.27:
            var start: Vector2 = verts[1]-Vector2(0,15)
            var end: Vector2 = verts[2]-Vector2(0,15)
            line(tread,[start,end],"73796e",2)
            if step%2==0:
                line(tread,[verts[1],start],"4b5859",2)
    # A tall octagonal masonry spindle makes the winding path legible in projection.
    var spindle := Node2D.new()
    spindle.name = "StoneSpindle"
    spindle.position = project(Vector2(512,512))
    spindle.set_meta("occlusion_height",118.0)
    spiral_root.add_child(spindle)
    var ring: Array = []
    for k in range(8):
        ring.append(project(polar(33,float(k)*TAU/8.0))-spindle.position)
    for k in range(8):
        var n: int = (k+1)%8
        polygon(spindle,[ring[k],ring[n],ring[n]-Vector2(0,100),ring[k]-Vector2(0,100)],"3c494b" if k<4 else "2c3b43")
        for course in range(1,7):
            var shift := Vector2(0,course*14)
            line(spindle,[ring[k]-shift,ring[n]-shift],"1d2c34")
            if k%2==course%2:
                var joint: Vector2 = (ring[k]+ring[n])*0.5-shift
                line(spindle,[joint,joint-Vector2(0,11)],"25343b")
    var cap: Array = []
    for k in range(8): cap.append(ring[k]-Vector2(0,100+(2 if k%3==0 else 0)))
    polygon(spindle,cap,"6e766a")
    line(spindle,[cap[0],cap[1],cap[2],cap[3],cap[4]],"8a8c78")
    walls.append(spindle)
    var occluder := LightOccluder2D.new()
    var shape := OccluderPolygon2D.new()
    shape.polygon = PackedVector2Array([Vector2(-46,-100),Vector2(0,-124),Vector2(46,-100),Vector2(46,0),Vector2(0,24),Vector2(-46,0)])
    occluder.occluder = shape
    spindle.add_child(occluder)
    # East upper landing aligns with the existing upstairs interaction zone.
    var landing := Node2D.new()
    landing.name = "UpperLanding"
    landing.position = project(Vector2(584,496))
    spiral_root.add_child(landing)
    polygon(landing,[Vector2(-25,-64),Vector2(0,-52),Vector2(0,-44),Vector2(-25,-56)],"424e4c")
    polygon(landing,[Vector2(0,-52),Vector2(25,-64),Vector2(25,-56),Vector2(0,-44)],"303f44")
    diamond(landing,0,-64,25,12,"666c61")
    line(landing,[Vector2(-23,-64),Vector2(0,-52),Vector2(23,-64)],"8b8b76",1)
    # Ground-level access from the actual south spawn/corridor, not just a side gap.
    for step in range(8):
        var ramp := Node2D.new()
        ramp.position = project(Vector2(512,652-step*4.5))
        spiral_root.add_child(ramp)
        var h: int = roundi(float(step+1)*18.0/8.0)
        prism(ramp,17,8,h,"626b60","404e4b","2c3d43")
        line(ramp,[Vector2(-15,-h),Vector2(0,7-h),Vector2(15,-h)],"858a76")
    var sign := Label.new()
    sign.text = "上层" if game.current_level<2 else "下楼请沿台阶返回"
    sign.add_theme_font_size_override("font_size",9)
    sign.modulate = Color("a8b2a3")
    sign.position = Vector2(-20,-94)
    landing.add_child(sign)

func stair_elevation_at(ground: Vector2) -> float:
    var local := ground-Vector2(512,512)
    var radius := local.length()
    if radius>SPIRAL_OUTER and radius<=140.0 and absf(wrapf(local.angle()-PI*0.5,-PI,PI))<0.27:
        return roundf((140.0-radius)/36.0*18.0)
    if radius<SPIRAL_INNER or radius>SPIRAL_OUTER:
        return 0.0
    var angle := fposmod(local.angle(),TAU)
    var step: int = mini(floori(angle/TAU*SPIRAL_STEPS),SPIRAL_STEPS-1)
    return float(step+1)*SPIRAL_RISE/SPIRAL_STEPS

func sync_objects() -> void:
    if not is_instance_valid(dynamic_root):
        return
    for child in dynamic_root.get_children():
        dynamic_root.remove_child(child)
        child.queue_free()
    for o in game.data.levels[game.current_level].objects:
        if o.type in ["stairs","light"]:
            continue
        var obj := Node2D.new()
        var base: Vector2
        if o.has("rect"):
            var r: Rect2 = game.region(o.rect)
            base = r.get_center()
        else:
            base = game.cell(o.cell)
        obj.position = project(base)
        dynamic_root.add_child(obj)
        if o.type in ["drop","break"]:
            obj.z_index = -15
            var hole: bool = o.type=="drop" or game.broken.has(o.id)
            diamond(obj,0,0,64,32,"070b10" if hole else "4a4940")
            line(obj,[Vector2(-64,0),Vector2(0,-32),Vector2(64,0),Vector2(0,32),Vector2(-64,0)],"6b6b5b",2)
            if hole:
                polygon(obj,[Vector2(-62,0),Vector2(0,-31),Vector2(62,0),Vector2(49,9),Vector2(0,-16),Vector2(-49,9)],"222d31")
            else:
                for k in [-24,0,24]:
                    line(obj,[Vector2(k-18,-9),Vector2(k-7,-3),Vector2(k-12,5),Vector2(k+4,11)],"141e24",2)
        if o.type=="chest":
            prism(obj,13,7,13,"77664b","4b3c2f","312e2a")
            for xx in [-6,6]:
                line(obj,[Vector2(xx,-16),Vector2(xx,-1)],"9b8e6b",2)
            polygon(obj,[Vector2(-2,-6),Vector2(2,-6),Vector2(2,-2),Vector2(-2,-2)],"b0a07a")
            if game.collected.has(o.id):
                line(obj,[Vector2(-12,-13),Vector2(0,-20),Vector2(12,-13)],"a6956d",3)
        if o.type=="gate":
            if not game.opened.has(o.id):
                for xx in range(-45,46,9):
                    line(obj,[Vector2(xx,-28+abs(xx)*0.25),Vector2(xx,8)],"6b7163",3)
                line(obj,[Vector2(-48,-17),Vector2(0,-42),Vector2(48,-17)],"4a5654",5)
            var button := Node2D.new()
            button.position = project(game.cell(o.button_cell))-obj.position
            obj.add_child(button)
            prism(button,5,3,8,"89917c","4a5a51","35454b")
    var candle_obj := Node2D.new()
    candle_obj.z_index = 200
    if game.current_level==2:
        candle_obj.position = project(game.cell([32,16]))
        dynamic_root.add_child(candle_obj)
        prism(candle_obj,10,5,12,"666b5e","3c4745","2d393f")
        polygon(candle_obj,[Vector2(-2,-13),Vector2(2,-13),Vector2(2,-24),Vector2(-2,-24)],"a29b7d")
        polygon(candle_obj,[Vector2(0,-29),Vector2(2,-25),Vector2(0,-23),Vector2(-1,-25)],"c4b78d")
    else:
        candle_obj.free()

func _process(_delta: float) -> void:
    if not is_instance_valid(avatar):
        return
    avatar.position = project(game.player.position)
    avatar.elevation = stair_elevation_at(game.player.position) + game.player.jump_height
    for wall in walls:
        var delta: Vector2 = wall.position-avatar.position
        # Fade only the wall directly obscuring the character, not all foreground masonry.
        wall.modulate.a = 0.32 if absf(delta.x)<24 and delta.y>0 and delta.y<float(wall.get_meta("occlusion_height",40.0)) else 1.0
