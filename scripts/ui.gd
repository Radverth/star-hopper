extends CanvasLayer

const FONT := preload("res://assets/fonts/KenneyBold.ttf")
const TEX_GET_READY := preload("res://assets/sprites/text_getready.png")
const TEX_GAME_OVER := preload("res://assets/sprites/text_gameover.png")
const TEX_TAP := preload("res://assets/sprites/tap.png")
const MEDALS := {
	50: preload("res://assets/sprites/medal_gold.png"),
	25: preload("res://assets/sprites/medal_silver.png"),
	10: preload("res://assets/sprites/medal_bronze.png"),
}

const GOLD := Color(1.0, 0.84, 0.27)
const INK := Color(0.05, 0.06, 0.12, 0.9)

var _score_label: Label
var _combo_label: Label
var _ready_group: Control
var _ready_best: Label
var _over_group: Control
var _over_score: Label
var _over_best: Label
var _over_streak: Label
var _over_record: Label
var _medal: TextureRect
var _flash: Label

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_score_label = _label("0", 104, Color.WHITE)
	_score_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_score_label.offset_top = 30.0
	_score_label.offset_bottom = 170.0
	root.add_child(_score_label)

	_combo_label = _label("", 44, GOLD)
	_combo_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_combo_label.offset_top = 178.0
	_combo_label.offset_bottom = 238.0
	_combo_label.modulate.a = 0.0
	root.add_child(_combo_label)

	_flash = _label("NEW BEST!", 58, GOLD)
	_flash.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_flash.offset_top = 248.0
	_flash.offset_bottom = 328.0
	_flash.modulate.a = 0.0
	root.add_child(_flash)

	root.add_child(_build_ready())
	root.add_child(_build_game_over())

# --- public API ---

func set_score(value: int) -> void:
	_score_label.text = str(value)
	_punch(_score_label, 1.22)

func set_multiplier(value: int) -> void:
	if value <= 1:
		if _combo_label.modulate.a > 0.0:
			_combo_label.create_tween().tween_property(_combo_label, "modulate:a", 0.0, 0.18)
		return
	var text := "x%d COMBO" % value
	var changed := _combo_label.text != text
	_combo_label.text = text
	_combo_label.modulate.a = 1.0
	if changed:
		_punch(_combo_label, 1.45)

func show_ready(best: int) -> void:
	_ready_best.text = "BEST  %d" % best if best > 0 else "TAP TO FLY"
	_ready_group.visible = true
	_ready_group.modulate.a = 1.0
	# The prompt owns the top of the screen until the run starts.
	_score_label.visible = false

func hide_ready() -> void:
	_score_label.visible = true
	var tween := _ready_group.create_tween()
	tween.tween_property(_ready_group, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func() -> void: _ready_group.visible = false)

func show_game_over(score: int, best: int, is_record: bool, streak: int) -> void:
	# The panel restates the score, so clear the in-flight HUD behind it.
	_score_label.visible = false
	_combo_label.modulate.a = 0.0
	_flash.modulate.a = 0.0

	_over_score.text = str(score)
	_over_best.text = str(best)
	_over_streak.text = "BEST STREAK  %d" % streak
	_over_record.visible = is_record
	_medal.texture = _medal_for(score)
	_medal.visible = _medal.texture != null

	_over_group.visible = true
	_over_group.modulate.a = 0.0
	_over_group.scale = Vector2(0.86, 0.86)
	_over_group.pivot_offset = _over_group.size * 0.5
	var tween := _over_group.create_tween().set_parallel()
	tween.tween_property(_over_group, "modulate:a", 1.0, 0.22)
	tween.tween_property(_over_group, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func flash_new_best() -> void:
	_flash.modulate.a = 1.0
	_punch(_flash, 1.6)
	var tween := _flash.create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.4)

func reset() -> void:
	_score_label.text = "0"
	_combo_label.modulate.a = 0.0
	_flash.modulate.a = 0.0
	_over_group.visible = false

# --- construction ---

func _build_ready() -> Control:
	# Centred in the upper 60% so the prompt sits clear of the hovering plane.
	_ready_group = _centered()
	_ready_group.anchor_bottom = 0.6

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 34)
	_ready_group.add_child(column)

	column.add_child(_texture(TEX_GET_READY))

	var tap := _texture(TEX_TAP)
	# The art is near-white, which vanishes against the pale sky.
	tap.modulate = Color(0.24, 0.33, 0.42)
	tap.pivot_offset = TEX_TAP.get_size() * 0.5
	column.add_child(tap)
	var bob := tap.create_tween().set_loops()
	bob.tween_property(tap, "scale", Vector2(1.18, 1.18), 0.5).set_trans(Tween.TRANS_SINE)
	bob.tween_property(tap, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)

	_ready_best = _label("", 40, Color.WHITE)
	column.add_child(_ready_best)
	return _ready_group

func _build_game_over() -> Control:
	_over_group = _centered()
	_over_group.visible = false

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 22)
	_over_group.add_child(column)

	column.add_child(_texture(TEX_GAME_OVER))

	_over_record = _label("NEW BEST!", 46, GOLD)
	column.add_child(_over_record)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", _panel_style())
	column.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	_medal = TextureRect.new()
	_medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_medal.custom_minimum_size = Vector2(114, 119)
	row.add_child(_medal)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override(&"separation", 2)
	row.add_child(stats)

	stats.add_child(_label("SCORE", 26, Color(1, 1, 1, 0.65)))
	_over_score = _label("0", 72, Color.WHITE)
	stats.add_child(_over_score)
	stats.add_child(_label("BEST", 26, Color(1, 1, 1, 0.65)))
	_over_best = _label("0", 44, GOLD)
	stats.add_child(_over_best)

	_over_streak = _label("", 28, Color(1, 1, 1, 0.75))
	column.add_child(_over_streak)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	var again := _label("TAP TO PLAY AGAIN", 36, Color.WHITE)
	column.add_child(again)
	var pulse := again.create_tween().set_loops()
	pulse.tween_property(again, "modulate:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(again, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

	return _over_group

# --- helpers ---

func _centered() -> Control:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return holder

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", INK)
	label.add_theme_constant_override(&"outline_size", maxi(6, size / 7))
	return label

func _texture(tex: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.custom_minimum_size = tex.get_size()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.11, 0.2, 0.94)
	style.border_color = Color(1, 1, 1, 0.2)
	style.set_border_width_all(4)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(24)
	return style

func _medal_for(score: int) -> Texture2D:
	for threshold: int in [50, 25, 10]:
		if score >= threshold:
			return MEDALS[threshold]
	return null

func _punch(node: Control, amount: float) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(amount, amount)
	node.create_tween().tween_property(node, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
