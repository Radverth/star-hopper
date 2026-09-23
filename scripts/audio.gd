extends Node

const POOL_SIZE := 10

const STREAMS := {
	&"flap": preload("res://assets/audio/flap.ogg"),
	&"star": preload("res://assets/audio/star.ogg"),
	&"score": preload("res://assets/audio/score.ogg"),
	&"crash": preload("res://assets/audio/crash.ogg"),
	&"gameover": preload("res://assets/audio/gameover.ogg"),
}

var _pool: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

func play(key: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream: AudioStream = STREAMS.get(key)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()
