extends SceneTree

# Renders real frames of the game to PNG so the visuals can be eyeballed.
#   xvfb-run -a godot --path . --script tests/screenshot.gd -- <out_dir>
# Captures the ready screen, mid-flight, and the game over panel.

const OUT_DEFAULT := "shots"
const WARMUP := 30

var _game: Node2D
var _player: Area2D
var _obstacles: Node2D
var _out := OUT_DEFAULT
var _frames := 0
var _shots := 0
var _done := false
var _stage := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_game = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	_player = _game.get_node("World/Player")
	_obstacles = _game.get_node("World/Obstacles")

func _process(_delta: float) -> bool:
	_frames += 1
	if _done:
		return true
	if _frames < WARMUP:
		return false

	match _stage:
		0:
			_shoot("01-ready")
			_stage = 1
		1:
			_tap()
			_stage = 2
		2:
			_autopilot()
			if _game.score >= 6:
				_shoot("02-flight")
				_stage = 3
		3:
			_autopilot()
			if _game.score >= 14:
				_shoot("03-combo")
				_stage = 4
		4:
			# Stop flying and let it crash, then wait for the panel to settle
			# rather than guessing a frame count (software GL is slow).
			if _game._restart_ready:
				_stage = 5
				_frames = 0
		5:
			if _frames > 60:
				_shoot("04-gameover")
				_done = true

	if _frames > 4000:
		_done = true
	return false

func _shoot(name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, name])
	_shots += 1
	print("captured %s (%dx%d)" % [name, image.get_width(), image.get_height()])

func _autopilot() -> void:
	var target := _target_y()
	if _player.position.y > target + 14.0 and _player.velocity_y > -120.0:
		_tap()

func _target_y() -> float:
	var ahead: Node2D = null
	for obstacle: Node2D in _obstacles.get_children():
		if obstacle.position.x + 70.0 < _player.position.x:
			continue
		if ahead == null or obstacle.position.x < ahead.position.x:
			ahead = obstacle
	if ahead == null:
		return root.get_visible_rect().size.y * 0.5
	if ahead.has_star and not ahead.star_taken:
		return ahead.position.y + (ahead.get_node("Star") as Area2D).position.y
	return ahead.gap_center

func _tap() -> void:
	var event := InputEventAction.new()
	event.action = &"flap"
	event.pressed = true
	Input.parse_input_event(event)
