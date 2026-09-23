extends Node2D

enum State { READY, PLAYING, DEAD }

const ObstacleScene := preload("res://scenes/Obstacle.tscn")
const PuffTexture := preload("res://assets/sprites/puff.png")
const ScoreFont := preload("res://assets/fonts/KenneyBold.ttf")

const GROUND_H := 71.0
const SKY_H := 480.0
const SKY_W := 800.0
const SPAWN_X := 660.0
const DESPAWN_X := -180.0

const BASE_SPEED := 265.0
const MAX_SPEED := 470.0
const BASE_GAP := 345.0
const MIN_GAP := 248.0
const BASE_SPACING := 360.0
const MAX_SPACING := 455.0
const RAMP_GATES := 40.0

const STAR_CHANCE := 0.85
const STAR_INSET := 62.0
const EDGE_MARGIN := 40.0
const MAX_CENTER_STEP := 235.0

const GOLD := Color(1.0, 0.84, 0.27)

@onready var _world: Node2D = $World
@onready var _sky: Node2D = $World/Sky
@onready var _ground: Node2D = $World/Ground
@onready var _obstacles: Node2D = $World/Obstacles
@onready var _effects: Node2D = $World/Effects
@onready var _player: Area2D = $World/Player
@onready var _ui: CanvasLayer = $UI

var state := State.READY
var score := 0
var streak := 0
var gates := 0

var _ground_y := 889.0
var _run_best_streak := 0
var _spawn_dist := 0.0
var _last_center := 480.0
var _beat_best := false
var _restart_ready := false
var _shake := 0.0

func _ready() -> void:
	randomize()
	_fit_to_viewport()
	_player.area_entered.connect(_on_player_area_entered)
	_ui.show_ready(Save.high_score)

# The viewport keeps a 540px width but grows vertically to match the device,
# so the ground line and the sky tiling are derived rather than hard-coded.
func _fit_to_viewport() -> void:
	var view_h := get_viewport_rect().size.y
	_ground_y = view_h - GROUND_H
	_ground.position.y = _ground_y
	_last_center = view_h * 0.5

	var sky_scale := view_h / SKY_H
	for tile: Sprite2D in _sky.get_children():
		tile.scale = Vector2(sky_scale, sky_scale)
	_sky.tile_width = SKY_W * sky_scale

	_player.set_home(view_h * 0.52)

func _process(delta: float) -> void:
	match state:
		State.READY:
			_scroll(BASE_SPEED * 0.4, delta)
			_player.advance(delta)
		State.PLAYING:
			var speed := _speed()
			_scroll(speed, delta)
			_player.advance(delta)
			_drive_obstacles(speed, delta)
			if _player.position.y >= _ground_y - 26.0:
				_crash()
		State.DEAD:
			_player.advance(delta)
			if _player.position.y >= _ground_y - 26.0:
				_player.position.y = _ground_y - 26.0
				_player.velocity_y = 0.0
	_apply_shake(delta)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_tap(event):
		return
	match state:
		State.READY:
			_start_run()
		State.PLAYING:
			_flap()
		State.DEAD:
			if _restart_ready:
				_reset_run()

# InputEventScreenTouch does not take part in action matching, so a mapped
# touch event never satisfies is_action_pressed() and every tap on a phone
# would be ignored. Touch is therefore checked directly, while keyboard and
# mouse still go through the "flap" action.
func _is_tap(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch != null:
		return touch.pressed
	return event.is_action_pressed(&"flap")

# --- run lifecycle ---

func _start_run() -> void:
	state = State.PLAYING
	_spawn_dist = BASE_SPACING
	_last_center = get_viewport_rect().size.y * 0.5
	_ui.hide_ready()
	_player.launch()
	Audio.play(&"flap", randf_range(0.94, 1.08), -4.0)
	_spawn_puff()

func _reset_run() -> void:
	for obstacle in _obstacles.get_children():
		obstacle.queue_free()
	for effect in _effects.get_children():
		effect.queue_free()
	score = 0
	streak = 0
	gates = 0
	_run_best_streak = 0
	_beat_best = false
	_restart_ready = false
	_shake = 0.0
	_world.position = Vector2.ZERO
	_player.reset()
	state = State.READY
	_ui.reset()
	_ui.show_ready(Save.high_score)

func _crash() -> void:
	state = State.DEAD
	_player.kill()
	_shake = 1.0
	Audio.play(&"crash", randf_range(0.9, 1.05))
	var is_record := Save.submit_run(score, _run_best_streak)

	await get_tree().create_timer(0.75).timeout
	if state != State.DEAD:
		return
	Audio.play(&"gameover", 1.0, -3.0)
	_ui.show_game_over(score, Save.high_score, is_record, _run_best_streak)
	_restart_ready = true

# --- difficulty ---

func _difficulty() -> float:
	return clampf(float(gates) / RAMP_GATES, 0.0, 1.0)

func _speed() -> float:
	return lerpf(BASE_SPEED, MAX_SPEED, _difficulty())

func multiplier() -> int:
	if streak >= 10:
		return 5
	if streak >= 6:
		return 3
	if streak >= 3:
		return 2
	return 1

# --- world ---

func _scroll(speed: float, delta: float) -> void:
	_sky.advance(speed, delta)
	_ground.advance(speed, delta)

func _drive_obstacles(speed: float, delta: float) -> void:
	for obstacle: Node2D in _obstacles.get_children():
		obstacle.position.x -= speed * delta
		if obstacle.position.x < DESPAWN_X:
			obstacle.queue_free()

	_spawn_dist += speed * delta
	var spacing := lerpf(BASE_SPACING, MAX_SPACING, _difficulty())
	if _spawn_dist >= spacing:
		_spawn_dist -= spacing
		_spawn_obstacle()

func _spawn_obstacle() -> void:
	var gap := lerpf(BASE_GAP, MIN_GAP, _difficulty())
	var center := _pick_center(gap)
	_last_center = center

	var star_y := NAN
	if randf() < STAR_CHANCE:
		star_y = center + randf_range(-1.0, 1.0) * maxf(gap * 0.5 - STAR_INSET, 0.0)

	var obstacle := ObstacleScene.instantiate()
	obstacle.position = Vector2(SPAWN_X, 0.0)
	_obstacles.add_child(obstacle)
	obstacle.build(center, gap, star_y)

func _pick_center(gap: float) -> float:
	var lo := EDGE_MARGIN + gap * 0.5
	var hi := _ground_y - EDGE_MARGIN - gap * 0.5
	var near_lo := maxf(lo, _last_center - MAX_CENTER_STEP)
	var near_hi := minf(hi, _last_center + MAX_CENTER_STEP)
	if near_lo > near_hi:
		return randf_range(lo, hi)
	return randf_range(near_lo, near_hi)

# --- scoring ---

func _on_player_area_entered(area: Area2D) -> void:
	if state != State.PLAYING:
		return
	if area.is_in_group(&"rock"):
		_crash()
	elif area.is_in_group(&"star"):
		_collect_star(area)
	elif area.is_in_group(&"scorezone"):
		_pass_gate(area.get_parent())

func _collect_star(star: Area2D) -> void:
	var obstacle := star.get_parent()
	if obstacle.star_taken:
		return
	var where := star.global_position
	obstacle.take_star()

	streak += 1
	_run_best_streak = maxi(_run_best_streak, streak)
	var gained := 2 * multiplier()
	_add_score(gained)
	Audio.play(&"star", minf(1.0 + streak * 0.07, 1.9))
	_shake = maxf(_shake, 0.2)
	_float_text("+%d" % gained, where, GOLD)

func _pass_gate(obstacle: Node) -> void:
	if obstacle.scored:
		return
	obstacle.scored = true
	gates += 1

	var gained := multiplier()
	if obstacle.has_star and not obstacle.star_taken:
		streak = 0
	_add_score(gained)
	Audio.play(&"score", randf_range(0.97, 1.06), -7.0)

func _add_score(amount: int) -> void:
	score += amount
	_ui.set_score(score)
	_ui.set_multiplier(multiplier())
	if not _beat_best and Save.high_score > 0 and score > Save.high_score:
		_beat_best = true
		_shake = maxf(_shake, 0.35)
		_ui.flash_new_best()

# --- juice ---

func _flap() -> void:
	_player.flap()
	Audio.play(&"flap", randf_range(0.94, 1.08), -4.0)
	_spawn_puff()

func _spawn_puff() -> void:
	var puff := Sprite2D.new()
	puff.texture = PuffTexture
	puff.position = _player.position + Vector2(-42.0, 16.0)
	puff.z_index = -1
	_effects.add_child(puff)

	var tween := puff.create_tween().set_parallel()
	tween.tween_property(puff, "scale", Vector2(2.6, 2.6), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "position", puff.position + Vector2(-110.0, 24.0), 0.45)
	tween.tween_property(puff, "modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(puff.queue_free)

func _float_text(text: String, where: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(&"font", ScoreFont)
	label.add_theme_font_size_override(&"font_size", 46)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.06, 0.12, 0.85))
	label.add_theme_constant_override(&"outline_size", 10)
	label.position = where - Vector2(40.0, 30.0)
	_effects.add_child(label)

	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 90.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)

func _apply_shake(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(_shake - delta * 3.4, 0.0)
	var amp := _shake * _shake * 26.0
	_world.position = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
