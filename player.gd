class_name Player
extends Node2D
## The runner. Stays at a fixed x; main.gd scrolls the world past it.
## Origin = feet. Art lives in the "Sprite" child (AnimatedSprite2D), which uses the
## animations "run", "jump" and "attack"; any that are missing are skipped.
## With no Sprite child, a placeholder stickman is drawn instead.

const GRAVITY := 2400.0
const JUMP_SPEED := 900.0
const ATTACK_TIME := 0.25
const ATTACK_COOLDOWN := 0.35
const INVULN_TIME := 1.2

# Hitboxes relative to the origin. Tune these to match your art.
const BODY := Rect2(-14, -90, 28, 90)
const FIST := Rect2(10, -80, 50, 50)

var ground_y := 0.0
var vy := 0.0
var grounded := true
var falling := false     # fell into a pit; can't recover
var attack_left := 0.0
var attack_cd := 0.0
var invuln := 0.0
var anim_t := 0.0        # drives the placeholder stickman's legs
var run_t := 0.0         # per-animation clocks for the sprite
var jump_t := 0.0
var attack_t := 0.0

@onready var sprite: AnimatedSprite2D = get_node_or_null("Sprite")


func reset(p_ground_y: float, x: float) -> void:
	ground_y = p_ground_y
	position = Vector2(x, ground_y)
	vy = 0.0
	grounded = true
	falling = false
	attack_left = 0.0
	attack_cd = 0.0
	invuln = 0.0
	run_t = 0.0
	jump_t = 0.0
	attack_t = 0.0
	_update_animation()
	queue_redraw()


func step(delta: float, supported: bool) -> void:
	anim_t += delta
	run_t += delta
	jump_t += delta
	attack_t += delta
	attack_left = maxf(attack_left - delta, 0.0)
	attack_cd = maxf(attack_cd - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)

	vy += GRAVITY * delta
	position.y += vy * delta
	if position.y >= ground_y:
		if supported and not falling:
			position.y = ground_y
			vy = 0.0
			grounded = true
		else:
			falling = true
			grounded = false
	else:
		grounded = false

	_update_animation()
	queue_redraw()


func jump() -> void:
	if grounded:
		vy = -JUMP_SPEED
		grounded = false
		jump_t = 0.0


func attack() -> bool:
	if attack_cd > 0.0:
		return false
	attack_left = ATTACK_TIME
	attack_cd = ATTACK_COOLDOWN
	attack_t = 0.0
	return true


func hurt() -> void:
	invuln = INVULN_TIME


func respawn() -> void:
	position.y = ground_y - 260.0
	vy = 0.0
	falling = false
	grounded = false
	invuln = INVULN_TIME


func is_attacking() -> bool:
	return attack_left > 0.0


func is_invulnerable() -> bool:
	return invuln > 0.0


func body_rect() -> Rect2:
	return Rect2(position + BODY.position, BODY.size)


func attack_rect() -> Rect2:
	return Rect2(position + FIST.position, FIST.size)


func _blink_on() -> bool:
	return invuln <= 0.0 or int(invuln * 10.0) % 2 == 0


func _has_anim(anim: String) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim)


func _update_animation() -> void:
	if sprite == null:
		return
	sprite.visible = _blink_on()
	var anim := "run"
	var t := run_t
	if attack_left > 0.0 and _has_anim("attack"):
		anim = "attack"
		t = attack_t
	elif not grounded and _has_anim("jump"):
		anim = "jump"
		t = jump_t
	if not _has_anim(anim):
		return
	# Frames are stepped by hand (using the FPS and loop flag from the SpriteFrames),
	# so the sprite only animates while the game is actually running.
	var frames := sprite.sprite_frames
	var count := frames.get_frame_count(anim)
	if count == 0:
		return
	var frame := int(t * frames.get_animation_speed(anim))
	if frames.get_animation_loop(anim):
		frame = frame % count
	else:
		frame = mini(frame, count - 1)
	sprite.animation = anim
	sprite.frame = frame


func _draw() -> void:
	if Obstacle.DEBUG_HITBOXES:
		draw_rect(BODY, Color.RED, false, 2.0)
		if is_attacking():
			draw_rect(FIST, Color.YELLOW, false, 2.0)
	if not _blink_on():
		return
	if sprite != null:
		# No "attack" animation: draw a simple punch arm so the hit still reads.
		if is_attacking() and not _has_anim("attack"):
			draw_line(Vector2(0, -58), Vector2(58, -52), Color.BLACK, 9.0)
			draw_circle(Vector2(60, -52), 8.0, Color.BLACK)
		return
	# Placeholder stickman (no Sprite child)
	var c := Color.BLACK
	var swing := sin(anim_t * 14.0) * 18.0 if grounded else 14.0
	draw_circle(Vector2(0, -78), 11.0, c)
	draw_line(Vector2(0, -66), Vector2(0, -34), c, 5.0)
	draw_line(Vector2(0, -34), Vector2(-swing, 0), c, 5.0)
	draw_line(Vector2(0, -34), Vector2(swing, 0), c, 5.0)
	if attack_left > 0.0:
		draw_line(Vector2(0, -58), Vector2(58, -52), c, 5.0)
	else:
		draw_line(Vector2(0, -58), Vector2(-14 - swing * 0.4, -42), c, 5.0)
		draw_line(Vector2(0, -58), Vector2(14 + swing * 0.4, -42), c, 5.0)
