extends Area2D

const FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/plane1.png"),
	preload("res://assets/sprites/plane2.png"),
	preload("res://assets/sprites/plane3.png"),
]

const GRAVITY := 2350.0
const FLAP_VELOCITY := -690.0
const MAX_FALL := 1150.0
const CEILING_Y := -10.0

@onready var _sprite: Sprite2D = $Sprite

var velocity_y := 0.0
var alive := true
var hovering := true

var _home_y := 0.0
var _bob_t := 0.0
var _frame_t := 0.0

func _ready() -> void:
	_home_y = position.y

func set_home(y: float) -> void:
	_home_y = y
	position.y = y

func reset() -> void:
	velocity_y = 0.0
	alive = true
	hovering = true
	rotation = 0.0
	position.y = _home_y
	_bob_t = 0.0
	_sprite.scale = Vector2.ONE

func launch() -> void:
	hovering = false
	flap()

func flap() -> void:
	velocity_y = FLAP_VELOCITY
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(0.88, 1.14), 0.06)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func kill() -> void:
	alive = false
	velocity_y = minf(velocity_y, -260.0)

func advance(delta: float) -> void:
	_frame_t += delta * (24.0 if alive else 4.0)
	_sprite.texture = FRAMES[int(_frame_t) % FRAMES.size()]

	if hovering:
		_bob_t += delta
		position.y = _home_y + sin(_bob_t * 3.6) * 16.0
		return

	velocity_y = minf(velocity_y + GRAVITY * delta, MAX_FALL)
	position.y += velocity_y * delta

	if position.y < CEILING_Y and alive:
		position.y = CEILING_Y
		velocity_y = maxf(velocity_y, 0.0)

	var fall_t := clampf(inverse_lerp(FLAP_VELOCITY * 0.55, MAX_FALL * 0.7, velocity_y), 0.0, 1.0)
	var target := lerpf(-0.38, 1.3, fall_t)
	rotation = lerp_angle(rotation, target, 1.0 - pow(0.0009, delta))
