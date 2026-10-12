class_name Obstacle
extends Node2D
## One scrolling thing: brick wall, saw, pipe, flyer or water pit.
## main.gd builds these from the DEFS table, so new types are one line there.

## Set to true to see hitboxes (obstacles, player body, fist).
const DEBUG_HITBOXES := false

var kind := ""
var hitbox := Rect2()   # local space. Origin = bottom-centre; pits hang below the origin.
var breakable := false
var points := 0
var color := Color.WHITE
var has_art := false


func setup(p_kind: String, def: Dictionary) -> void:
	kind = p_kind
	var size: Vector2 = def["size"]
	if kind == "pit":
		hitbox = Rect2(Vector2(-size.x * 0.5, 0.0), size)
	else:
		hitbox = Rect2(Vector2(-size.x * 0.5, -size.y), size)
	breakable = def.get("breakable", false)
	points = def.get("points", 0)
	color = def.get("color", Color.WHITE)

	# Use your art if the file exists. Obstacles align bottom-centre, water aligns top-centre.
	var path: String = def.get("texture", "")
	if path != "" and ResourceLoader.exists(path):
		var sprite := Sprite2D.new()
		sprite.texture = load(path)
		sprite.centered = false
		var tex_size := sprite.texture.get_size()
		var y := 0.0 if kind == "pit" else -tex_size.y
		sprite.position = Vector2(-tex_size.x * 0.5, y)
		add_child(sprite)
		has_art = true


func world_rect() -> Rect2:
	return Rect2(position + hitbox.position, hitbox.size)


func _draw() -> void:
	if not has_art:
		if kind == "saw":
			draw_circle(hitbox.get_center(), hitbox.size.x * 0.5, color)
		else:
			draw_rect(hitbox, color)
	if DEBUG_HITBOXES:
		draw_rect(hitbox, Color.RED, false, 2.0)
