extends SceneTree

# Headless smoke test: boots the real scene, plays it with a crude autopilot,
# deliberately crashes, restarts, and plays on. Any engine or script error
# printed during the run fails the build (CI greps the output).

const MAX_FRAMES := 5400
const DIVE_AT := 2400 # stop flapping here to force a crash
const TEARDOWN_FRAMES := 5

var _game: Node2D
var _player: Area2D
var _obstacles: Node2D
var _frames := 0
var _teardown := 0
var _prev_state := -1
var _deaths := 0
var _restarts := 0
var _peak_score := 0
var _peak_streak := 0
var _saw_playing := false

func _initialize() -> void:
	_game = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	_player = _game.get_node("World/Player")
	_obstacles = _game.get_node("World/Obstacles")

func _process(_delta: float) -> bool:
	if _teardown > 0:
		_teardown -= 1
		return _teardown == 0

	_frames += 1
	if _frames < 5:
		return false

	_track_transitions()

	match _game.state:
		_game.State.READY:
			_tap()
		_game.State.PLAYING:
			_saw_playing = true
			_peak_score = maxi(_peak_score, _game.score)
			_peak_streak = maxi(_peak_streak, _game.streak)
			if _frames < DIVE_AT:
				_autopilot()
		_game.State.DEAD:
			_tap()

	if _frames >= MAX_FRAMES:
		if not _report():
			quit(1)
			return true
		_game.free()
		_game = null
		_player = null
		_obstacles = null
		_teardown = TEARDOWN_FRAMES
	return false

func _track_transitions() -> void:
	var now: int = _game.state
	if now != _prev_state:
		if now == _game.State.DEAD:
			_deaths += 1
		elif _prev_state == _game.State.DEAD:
			_restarts += 1
		_prev_state = now

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
	# Aim at the star when there is one, otherwise the middle of the gap.
	if ahead.has_star and not ahead.star_taken:
		return ahead.position.y + (ahead.get_node("Star") as Area2D).position.y
	return ahead.gap_center

func _tap() -> void:
	var event := InputEventAction.new()
	event.action = &"flap"
	event.pressed = true
	Input.parse_input_event(event)

func _report() -> bool:
	var save := root.get_node_or_null("/root/Save")
	print("--- smoke test ---")
	print("frames       : %d" % _frames)
	print("reached play : %s" % _saw_playing)
	print("peak score   : %d" % _peak_score)
	print("peak streak  : %d" % _peak_streak)
	print("deaths       : %d" % _deaths)
	print("restarts     : %d" % _restarts)
	print("saved best   : %d" % (save.high_score if save else -1))

	var ok: bool = (_saw_playing
		and _peak_score > 0
		and _peak_streak > 0
		and _deaths >= 1
		and _restarts >= 1
		and save != null
		and save.high_score >= _peak_score)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	return ok
