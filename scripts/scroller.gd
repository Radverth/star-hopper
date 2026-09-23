extends Node2D

@export var tile_width: float = 800.0
@export var factor: float = 1.0

var _offset: float = 0.0

func advance(speed: float, delta: float) -> void:
	_offset = fposmod(_offset - speed * factor * delta, tile_width)
	var tiles := get_children()
	for i in tiles.size():
		(tiles[i] as Node2D).position.x = _offset + tile_width * (i - 1)
