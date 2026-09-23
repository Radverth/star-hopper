extends Node

const SAVE_PATH := "user://starhopper.cfg"

var high_score: int = 0
var best_streak: int = 0
var runs: int = 0

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	high_score = cfg.get_value("progress", "high_score", 0)
	best_streak = cfg.get_value("progress", "best_streak", 0)
	runs = cfg.get_value("progress", "runs", 0)

func submit_run(score: int, streak: int) -> bool:
	var is_record := score > high_score
	high_score = maxi(high_score, score)
	best_streak = maxi(best_streak, streak)
	runs += 1

	var cfg := ConfigFile.new()
	cfg.set_value("progress", "high_score", high_score)
	cfg.set_value("progress", "best_streak", best_streak)
	cfg.set_value("progress", "runs", runs)
	cfg.save(SAVE_PATH)
	return is_record
