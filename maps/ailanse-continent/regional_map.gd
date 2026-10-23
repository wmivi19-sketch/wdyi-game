extends Control

var world: Node
var font: SystemFont
var map_rect:=Rect2(34,100,620,620)

func _ready() -> void:
	font=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC"])
	mouse_filter=Control.MOUSE_FILTER_STOP

func point(x: float,z: float) -> Vector2:
	return map_rect.position+Vector2((x+500)/1000,(z+500)/1000)*map_rect.size

func _draw() -> void:
	if world==null: return
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.04,0.07,0.065,1.0))
	draw_string(font,Vector2(34,45),"艾兰瑟平原 · 四镇区域图",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("e4d6b6"))
	draw_string(font,Vector2(34,77),"整图约 1000 × 1000 米  /  北 ↑  /  M 或 Esc 返回",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("b5bdab"))
	draw_rect(map_rect,Color("3c4b36"))
	for i in range(11):
		var d: float=i*62
		draw_line(map_rect.position+Vector2(d,0),map_rect.position+Vector2(d,620),Color(0.8,0.85,0.7,0.08))
		draw_line(map_rect.position+Vector2(0,d),map_rect.position+Vector2(620,d),Color(0.8,0.85,0.7,0.08))
	draw_rect(Rect2(point(420,-500),Vector2(49.6,620)),Color("416571"))
	for i in range(10):
		var p:=point(-440+i*85,-435)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-24,20),p+Vector2(0,-18-float(i%3)*8),p+Vector2(30,20)]),Color("88877a"))
	draw_string(font,point(-270,-390),"弗罗林斯山脉",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e0d6b8"))
	draw_string(font,point(345,-80),"黄石滩",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e0d6b8"))
	for parcel in world.landscape.parcels:
		var crop_color: Color=Color("738348") if parcel.crop=="vine" else (Color("b49a54") if parcel.crop=="wheat" else Color("7598a3"))
		var corner:=point(parcel.center[0]-parcel.size[0]/2,parcel.center[1]-parcel.size[1]/2)
		draw_rect(Rect2(corner,Vector2(parcel.size[0],parcel.size[1])*0.62),crop_color)
	for z in [-250,250]: draw_line(point(-480,z),point(390,z),Color("a6a28d"),4)
	for x in [-236,264]: draw_line(point(x,-390),point(x,480),Color("a6a28d"),3)
	for i in range(world.regions.size()):
		var region: Dictionary=world.regions[i]
		var c: Array=region.center
		var p:=point(c[0],c[1])
		var color: Color=[Color("9f725d"),Color("9f725d"),Color("c3aa5c"),Color("7c9aaf")][i]
		draw_rect(Rect2(p-Vector2(50,37),Vector2(100,74)),color.darkened(0.3))
		draw_rect(Rect2(p-Vector2(50,37),Vector2(100,74)),color,false,2)
		draw_circle(p,6,color)
		draw_string(font,p+Vector2(-49,58),str(i+1)+" "+region.name,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e9dfc5"))
		if world.visited.has(region.id): draw_string(font,p+Vector2(-24,-44),"已到访",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("bdd1a1"))
	var pp:=point(world.player.position.x,world.player.position.z)
	draw_circle(pp,7,Color("9ccdf1"))
	draw_circle(pp,3,Color.WHITE)
	draw_line(Vector2(40,748),Vector2(164,748),Color("d8c9a7"),2)
	draw_string(font,Vector2(42,770),"200 米",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d8c9a7"))

func refresh() -> void:
	queue_redraw()
