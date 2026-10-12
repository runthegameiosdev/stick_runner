extends Node2D

enum State { READY, PLAYING, PAUSED, GAME_OVER }

const PLAYER_X := 180.0
const GROUND_RATIO := 0.75   # ground height as a fraction of screen height
const BASE_SPEED := 480.0    # px per second
const SPEED_PER_LEVEL := 50.0
const MAX_SPEED := 900.0
const SCORE_PER_PX := 0.0625   # distance score: about 30 points/sec at base speed
const LEVEL_STEP := 700      # score needed per level
const START_LIVES := 3
const SAVE_PATH := "user://save.cfg"

# Obstacle table. Add a line here to add a new type, then add its name to SPAWN_TABLE.
# size    = hitbox in px (pit: width, depth). Things stand on the ground, origin = bottom-centre.
# height  = lift off the ground (flyers)
# texture = your art; if the file is missing, a coloured box is drawn instead
const DEFS := {
	"bricks": {"size": Vector2(48, 80), "breakable": true, "points": 10, "color": Color(0.76, 0.27, 0.18), "texture": "res://art/bricks.png"},
	"saw": {"size": Vector2(52, 52), "color": Color(0.6, 0.64, 0.68), "texture": "res://art/saw.png"},
	"pipe": {"size": Vector2(56, 120), "color": Color(0.43, 0.49, 0.54), "texture": "res://art/pipe.png"},
	"flyer": {"size": Vector2(70, 40), "breakable": true, "points": 3, "height": 60.0, "color": Color(0.29, 0.64, 0.87), "texture": "res://art/flyer.png"},
	"pit": {"size": Vector2(120, 400), "color": Color(0.18, 0.53, 0.84), "texture": "res://art/water.png"},
}
const SPAWN_TABLE := ["bricks", "bricks", "saw", "pipe", "flyer", "pit"]

## Untick once your own background/ground art is in the scene.
@export var draw_placeholder_world := true

@onready var world: Node2D = $World
@onready var player: Player = $Player
@onready var score_label: Label = $HUD/ScoreLabel
@onready var best_label: Label = $HUD/BestLabel
@onready var level_label: Label = $HUD/LevelLabel
@onready var lives_label: Label = $HUD/LivesLabel
@onready var message: Label = $HUD/MessageLabel
@onready var attack_button: Control = $HUD/AttackButton
@onready var pause_button: Control = $HUD/PauseButton
@onready var sky: TextureRect = get_node_or_null("Background/Sky")

var state := State.READY
var ground_y := 0.0
var obstacles: Array = []
var score := 0.0
var best := 0
var lives := START_LIVES
var level := 1
var next_level_at := LEVEL_STEP
var speed := BASE_SPEED
var scroll := 0.0
var next_spawn_in := 0.0
var restart_lock := 0.0


func _ready() -> void:
	ground_y = get_viewport_rect().size.y * GROUND_RATIO
	_load_best()
	player.reset(ground_y, PLAYER_X)
	message.text = "TAP TO START"
	_update_hud()


# --- Input -----------------------------------------------------------------
# Touch: ATTACK button = attack, pause button = pause, anywhere else = jump.
# Desktop: click works the same (mouse is emulated as touch); Space / J / P also work.

func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_press(_action_for_tap(touch.position))
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.physical_keycode:
			KEY_SPACE:
				_press("jump")
			KEY_J:
				_press("attack")
			KEY_P:
				_press("pause")


func _action_for_tap(pos: Vector2) -> String:
	if pause_button.get_global_rect().has_point(pos):
		return "pause"
	if attack_button.get_global_rect().has_point(pos):
		return "attack"
	return "jump"


func _press(action: String) -> void:
	match state:
		State.READY:
			_start_run()
		State.GAME_OVER:
			if restart_lock <= 0.0:
				_start_run()
		State.PAUSED:
			_set_paused(false)
		State.PLAYING:
			match action:
				"jump":
					player.jump()
				"attack":
					player.attack()
				"pause":
					_set_paused(true)


# --- Game flow -------------------------------------------------------------

func _start_run() -> void:
	for o in obstacles:
		o.queue_free()
	obstacles.clear()
	score = 0.0
	lives = START_LIVES
	level = 1
	next_level_at = LEVEL_STEP
	speed = BASE_SPEED
	scroll = 0.0
	next_spawn_in = 500.0
	player.reset(ground_y, PLAYER_X)
	message.hide()
	state = State.PLAYING
	_update_hud()


func _set_paused(paused: bool) -> void:
	state = State.PAUSED if paused else State.PLAYING
	message.text = "PAUSED\nTap to resume"
	message.visible = paused


func _game_over() -> void:
	state = State.GAME_OVER
	restart_lock = 0.6
	best = maxi(best, int(score))
	_save_best()
	message.text = "GAME OVER\nTap to restart"
	message.show()
	_update_hud()


func _process(delta: float) -> void:
	restart_lock = maxf(restart_lock - delta, 0.0)
	if state != State.PLAYING:
		return
	delta = minf(delta, 0.05)

	speed = minf(BASE_SPEED + (level - 1) * SPEED_PER_LEVEL, MAX_SPEED)
	var dist := speed * delta
	scroll += dist
	score += dist * SCORE_PER_PX
	if int(score) >= next_level_at:
		level += 1
		next_level_at += LEVEL_STEP
		_popup("LEVEL UP!", Vector2(get_viewport_rect().size.x * 0.5 - 90.0, ground_y - 280.0))

	for o in obstacles.duplicate():
		o.position += Vector2(-dist, 0.0)
		if o.position.x < -200.0:
			_remove(o)

	next_spawn_in -= dist
	if next_spawn_in <= 0.0:
		_spawn()
		next_spawn_in = speed * randf_range(1.1, 1.8)

	player.step(delta, not _over_pit())
	_check_hits()
	if state == State.PLAYING and player.falling and player.position.y > ground_y + 160.0:
		_fell_in_pit()

	_update_hud()
	queue_redraw()


# --- Obstacles, hits, pits -------------------------------------------------

func _spawn() -> void:
	var kind: String = SPAWN_TABLE.pick_random()
	var def: Dictionary = DEFS[kind]
	var obs := Obstacle.new()
	obs.setup(kind, def)
	obs.position = Vector2(get_viewport_rect().size.x + 100.0, ground_y - float(def.get("height", 0.0)))
	world.add_child(obs)
	obstacles.append(obs)


func _remove(o) -> void:
	obstacles.erase(o)
	o.queue_free()


func _over_pit() -> bool:
	for o in obstacles:
		if o.kind == "pit":
			var r: Rect2 = o.world_rect()
			if player.position.x > r.position.x + 10.0 and player.position.x < r.end.x - 10.0:
				return true
	return false


func _check_hits() -> void:
	var body := player.body_rect()
	var fist := player.attack_rect()
	for o in obstacles.duplicate():
		if o.kind == "pit":
			continue
		var r: Rect2 = o.world_rect()
		if o.breakable and player.is_attacking() and fist.intersects(r):
			_smash(o)
		elif not player.is_invulnerable() and body.intersects(r):
			_remove(o)
			_hurt()
			if state != State.PLAYING:
				return


func _smash(o) -> void:
	score += o.points
	_popup("+%d" % o.points, o.position + Vector2(-20.0, -o.hitbox.size.y - 20.0))
	_remove(o)


func _hurt() -> void:
	lives -= 1
	if lives <= 0:
		_game_over()
	else:
		player.hurt()


func _fell_in_pit() -> void:
	lives -= 1
	if lives <= 0:
		_game_over()
		return
	# Clear everything near the player (including the pit) and drop them back in.
	for o in obstacles.duplicate():
		if o.position.x < PLAYER_X + 450.0:
			_remove(o)
	player.respawn()


# --- HUD, popups, drawing, saving -----------------------------------------

func _update_hud() -> void:
	score_label.text = "SCORE: %d" % int(score)
	best_label.text = "BEST: %d" % best
	level_label.text = "LEVEL UP AT: %d" % next_level_at
	lives_label.text = "LIVES: %d" % lives


func _popup(text: String, pos: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 70.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.finished.connect(label.queue_free)


func _draw() -> void:
	if not draw_placeholder_world:
		return
	var w := get_viewport_rect().size.x
	if sky == null or sky.texture == null:
		draw_rect(Rect2(-10, 0, w + 20, ground_y), Color(0.55, 0.83, 0.96))
	draw_rect(Rect2(-10, ground_y, w + 20, 2000), Color(0.48, 0.29, 0.17))
	draw_rect(Rect2(-10, ground_y, w + 20, 16), Color(0.73, 0.73, 0.73))
	var x := -fmod(scroll, 60.0)
	while x < w:
		draw_line(Vector2(x, ground_y), Vector2(x, ground_y + 16.0), Color(0.55, 0.55, 0.55), 2.0)
		x += 60.0


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best = int(cfg.get_value("game", "best", 0))


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", best)
	cfg.save(SAVE_PATH)
