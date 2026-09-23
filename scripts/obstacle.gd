extends Node2D

# Rock sprites are 108x239 cones. Slicing off the outlined cap and stretching a
# 2px cross-section lets a gate reach any height without a visible seam.
const ROCK_W := 108.0
const TOP_TIP := Rect2(0, 2, 108, 237)
const TOP_SLICE := Rect2(0, 2, 108, 2)
const BOTTOM_TIP := Rect2(0, 0, 108, 235)
const BOTTOM_SLICE := Rect2(0, 233, 108, 2)
const TOP_EXTENT := -200.0
const BOTTOM_EXTENT := 1700.0

# Rect bands approximating the cone, inset from the art so near-misses survive.
# Each entry is (start distance from tip, end distance, width).
const BANDS := [
	Vector3(22.0, 110.0, 30.0),
	Vector3(110.0, 235.0, 66.0),
	Vector3(235.0, 1700.0, 92.0),
]

@onready var _top_tip: Sprite2D = $TopTip
@onready var _top_body: Sprite2D = $TopBody
@onready var _bottom_tip: Sprite2D = $BottomTip
@onready var _bottom_body: Sprite2D = $BottomBody
@onready var _star: Area2D = $Star

var gap_center := 0.0
var gap_size := 0.0
var has_star := false
var star_taken := false
var scored := false

func build(center: float, size: float, star_y: float) -> void:
	gap_center = center
	gap_size = size
	var gap_top := center - size * 0.5
	var gap_bottom := center + size * 0.5

	_top_tip.region_rect = TOP_TIP
	_top_tip.position = Vector2(-ROCK_W * 0.5, gap_top - TOP_TIP.size.y)
	_shape_body(_top_body, TOP_SLICE, TOP_EXTENT, gap_top - TOP_TIP.size.y)

	_bottom_tip.region_rect = BOTTOM_TIP
	_bottom_tip.position = Vector2(-ROCK_W * 0.5, gap_bottom)
	_shape_body(_bottom_body, BOTTOM_SLICE, gap_bottom + BOTTOM_TIP.size.y, BOTTOM_EXTENT)

	_add_bands($TopArea, gap_top, -1.0)
	_add_bands($BottomArea, gap_bottom, 1.0)

	has_star = not is_nan(star_y)
	_star.visible = has_star
	_star.monitorable = has_star
	if has_star:
		_star.position.y = star_y

func take_star() -> void:
	star_taken = true
	# Called from the player's area_entered handler, so this cannot be direct.
	_star.set_deferred(&"monitorable", false)
	var tween := create_tween().set_parallel()
	tween.tween_property(_star, "scale", Vector2(2.2, 2.2), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_star, "modulate:a", 0.0, 0.22)

func _process(delta: float) -> void:
	if has_star and not star_taken:
		_star.rotation += delta * 1.7

func _shape_body(body: Sprite2D, slice: Rect2, top: float, bottom: float) -> void:
	var height := bottom - top
	if height <= 0.0:
		body.visible = false
		return
	body.region_rect = slice
	body.position = Vector2(-ROCK_W * 0.5, top)
	body.scale.y = height / slice.size.y

func _add_bands(area: Area2D, tip_y: float, dir: float) -> void:
	for band: Vector3 in BANDS:
		var height := band.y - band.x
		var shape := RectangleShape2D.new()
		shape.size = Vector2(band.z, height)
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.position = Vector2(0.0, tip_y + dir * (band.x + height * 0.5))
		area.add_child(collider)
