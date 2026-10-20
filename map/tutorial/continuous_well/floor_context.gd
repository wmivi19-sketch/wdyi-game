extends Node
var data: Dictionary
var current_level: int
var player
var opened: Dictionary
var broken: Dictionary
var collected: Dictionary
func cell(v: Array) -> Vector2:
    return Vector2(float(v[0])*16+8,float(v[1])*16+8)
func region(r: Array) -> Rect2:
    return Rect2(float(r[0])*16,float(r[1])*16,float(r[2])*16,float(r[3])*16)
