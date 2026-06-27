extends Control

const PLAYER_MAX_HP := 10
const BOSS_MAX_HP := 20
const BOSS_HP_ENV := "MATH_WAR_BOSS_HP"
const GAME_DISPLAY_NAME := "Math Knight"
const BASE_DAMAGE := 1
const MAX_ROUNDS := 20
const MAX_ANSWER_DIGITS := 6
const ANSWER_EPSILON := 0.001
const BATTLE_FRAME_MAX_WIDTH := 1120
const BATTLE_FRAME_MARGIN := 24
const BATTLE_FRAME_PADDING := 24
const BATTLE_BOARD_GAP := 16
const PANEL_PADDING := 18
const RIGHT_COLUMN_WIDTH := 430
const PORTRAIT_BREAKPOINT := 900
const COMBATANT_PANEL_HEIGHT := 132
const COMBATANT_PANEL_HEIGHT_PORTRAIT := 132
const QUESTION_PANEL_HEIGHT := 318
const QUESTION_PANEL_HEIGHT_PORTRAIT := 240
const QUESTION_STACK_HEIGHT := 282
const QUESTION_STACK_HEIGHT_PORTRAIT := 204
const LOG_PANEL_HEIGHT := 132
const KEYPAD_PANEL_HEIGHT := 466
const KEYPAD_ANSWER_HEIGHT := 76
const KEYPAD_KEY_HEIGHT := 58
const KEYPAD_KEY_GAP := 6
const KEYPAD_INNER_PADDING := 8
const AVATAR_SIZE := 88
const STATS_CARD_ROW_HEIGHT := 88
const STATS_CHART_HEIGHT := 190
const STATS_HISTORY_HEIGHT := 190
const STATS_FILE_PATH := "user://math_knight_stats.json"
const PLAYER_SAVES_FILE_PATH := "user://math_knight_players.json"
const SERIES_OPTIONS_PATH := "res://assets/config/series_options.json"
const PLAYER_SAVE_COUNT := 5
const UI_PADDING_SMALL := 8
const UI_PADDING_MEDIUM := 14

var COLOR_BACKGROUND := Color("#eee2c8")
var COLOR_PRIMARY := Color("#fff8e8")
var COLOR_PRIMARY_LIGHT := Color("#fff8e8")
var COLOR_SECONDARY := Color("#b9822f")
var COLOR_SECONDARY_DARK := Color("#c9b58a")
var COLOR_TEXT := Color("#2b2418")
var COLOR_MUTED_TEXT := Color("#5f513e")
var COLOR_HEALTH := Color("#c9963f")
var COLOR_STATE := Color("#5f513e")
var COLOR_BUTTON := Color("#fff8e8")
var COLOR_BUTTON_ACTIVE := Color("#f4e5bd")
var COLOR_CORRECT := Color("#2e9d50")
var COLOR_WRONG := Color("#c0392b")

const ICON_PAUSE_PATH := "res://assets/icons/ic_fluent_pause_24_filled.png"
const ICON_PLAY_PATH := "res://assets/icons/ic_fluent_play_24_filled.png"
const ICON_BACK_PATH := "res://assets/icons/ic_fluent_arrow_left_24_filled.png"
const ICON_RETRY_PATH := "res://assets/icons/ic_fluent_arrow_clockwise_24_filled.png"
const ICON_HOME_PATH := "res://assets/icons/ic_fluent_home_24_filled.png"
const ICON_ERASER_PATH := "res://assets/icons/ic_fluent_eraser_24_filled.png"
const ICON_DARK_THEME_PATH := "res://assets/icons/ic_fluent_dark_theme_20_filled.png"
const PLAYER_SPRITE_PATH := "res://assets/sprites/player_math_knight.png"
const BOSS_SPRITE_PATH := "res://assets/sprites/boss_hive_calculator.png"
const UI_FONT_PATH := "res://assets/fonts/MapleMono-NF-CN-Light.ttf"

var player_hp := PLAYER_MAX_HP
var boss_hp := BOSS_MAX_HP
var boss_max_hp := BOSS_MAX_HP
var current_count := 0
var round_index := 0
var current_answer := 0.0
var game_over := false
var is_paused := false
var rng := RandomNumberGenerator.new()

var screen_root: Control
var background_rect: ColorRect
var title_label: Label
var boss_hp_label: Label
var player_hp_label: Label
var boss_hp_bar: ProgressBar
var player_hp_bar: ProgressBar
var question_stack: Control
var question_pause_overlay: PanelContainer
var previous_question_label: Label
var current_question_label: Label
var next_question_label: Label
var question_tween: Tween
var feedback_label: Label
var answer_display: Label
var submit_hint_label: Label
var submit_hint_sub_label: Label
var pause_button: Button
var exit_button: Button
var icon_pause: Texture2D
var icon_play: Texture2D
var icon_back: Texture2D
var icon_retry: Texture2D
var icon_home: Texture2D
var icon_eraser: Texture2D
var icon_dark_theme: Texture2D
var player_sprite: Texture2D
var boss_sprite: Texture2D
var ui_font: Font
var keypad_buttons := []
var log_label: RichTextLabel
var answer_text := ""
var previous_problem := {}
var current_problem := {}
var next_problem := {}
var generated_question_texts := {}
var in_battle_screen := false
var current_battle_portrait_layout := false
var selected_user := "玩家1"
var selected_player_index := 0
var selected_series_index := 0
var difficulty_cards_scroll: ScrollContainer
var difficulty_cards_scroll_horizontal := 0
var difficulty_cards_press_position := Vector2.ZERO
var difficulty_cards_press_scroll := 0
var difficulty_cards_dragging := false
var question_started_msec := 0
var question_accumulated_msec := 0
var correct_count := 0
var wrong_count := 0
var total_valid_duration := 0.0
var min_duration := 0.0
var max_duration := 0.0
var max_streak_count := 0
var correct_records := []
var answer_records := []
var current_stats_saved := false
var dark_skin_enabled := false

var player_names := ["玩家1", "玩家2", "玩家3", "玩家4", "玩家5"]
var series_options := []

func _ready() -> void:
	rng.randomize()
	_build_series_options()
	if series_options.is_empty():
		return
	_load_player_saves()
	_load_font()
	_load_icons()
	_load_sprites()
	_build_base_ui()
	_apply_theme()
	_show_start_screen()


func _build_series_options() -> void:
	series_options = _load_series_options_from_config()


func _load_series_options_from_config() -> Array:
	var file := FileAccess.open(SERIES_OPTIONS_PATH, FileAccess.READ)
	if file == null:
		push_error("无法读取难度配置：%s" % SERIES_OPTIONS_PATH)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		push_error("难度配置格式错误：根节点必须是数组。")
		return []
	var loaded := []
	for item in parsed:
		if not (item is Dictionary):
			push_error("难度配置格式错误：每一项必须是对象。")
			return []
		var option: Dictionary = item
		var key := str(option.get("key", "")).strip_edges()
		var name := str(option.get("name", "")).strip_edges()
		var op := str(option.get("op", "")).strip_edges()
		if key.is_empty() or name.is_empty() or op.is_empty():
			push_error("难度配置格式错误：key、name 和 op 不能为空。")
			return []
		loaded.append({"key": key, "name": name, "op": op})
	if loaded.is_empty():
		push_error("难度配置为空：%s" % SERIES_OPTIONS_PATH)
		return []
	return loaded


func _build_base_ui() -> void:
	background_rect = ColorRect.new()
	background_rect.anchor_right = 1.0
	background_rect.anchor_bottom = 1.0
	background_rect.offset_right = 0
	background_rect.offset_bottom = 0
	background_rect.color = COLOR_BACKGROUND
	add_child(background_rect)

	screen_root = Control.new()
	screen_root.anchor_right = 1.0
	screen_root.anchor_bottom = 1.0
	screen_root.offset_right = 0
	screen_root.offset_bottom = 0
	add_child(screen_root)


func _clear_screen() -> void:
	_release_ui_focus()
	difficulty_cards_scroll = null
	for child in screen_root.get_children():
		if child is Control:
			var control := child as Control
			control.visible = false
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.queue_free()


func _make_standard_screen_root(title_text: String, title_size: int, actions: Array) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.anchor_right = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = BATTLE_FRAME_MARGIN
	frame.offset_top = BATTLE_FRAME_MARGIN
	frame.offset_right = -BATTLE_FRAME_MARGIN
	frame.offset_bottom = -BATTLE_FRAME_MARGIN
	frame.add_theme_stylebox_override("panel", _make_battle_frame_style())
	screen_root.add_child(frame)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 18)
	frame.add_child(root)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 56)
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var header_left_spacer := Control.new()
	header_left_spacer.custom_minimum_size = Vector2(120, 0)
	header.add_child(header_left_spacer)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", COLOR_SECONDARY)
	_apply_font(title, title_size, "font")
	header.add_child(title)

	var header_actions := HBoxContainer.new()
	header_actions.custom_minimum_size = Vector2(120, 0)
	header_actions.alignment = BoxContainer.ALIGNMENT_END
	header_actions.add_theme_constant_override("separation", 8)
	header.add_child(header_actions)
	for action in actions:
		if action is Control:
			header_actions.add_child(action)
	return root


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and in_battle_screen:
		call_deferred("_rebuild_battle_ui_if_layout_changed")


func _input(event: InputEvent) -> void:
	if _handle_difficulty_cards_touch_input(event):
		get_viewport().set_input_as_handled()


func _show_start_screen() -> void:
	in_battle_screen = false
	_clear_screen()

	var theme_button := _make_header_icon_button(icon_dark_theme, "切换皮肤")
	theme_button.pressed.connect(_toggle_skin)
	var root := _make_standard_screen_root(GAME_DISPLAY_NAME, 32, [theme_button])

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", BATTLE_BOARD_GAP)
	root.add_child(box)

	var saves_section := _make_start_section("选择存档")
	var saves_box: VBoxContainer = saves_section.get_child(0)
	saves_box.add_child(_make_player_cards())
	box.add_child(saves_section)

	var difficulty_section := _make_start_section("选择难度")
	var difficulty_box: VBoxContainer = difficulty_section.get_child(0)
	difficulty_box.add_child(_make_difficulty_cards())
	box.add_child(difficulty_section)

	var hint := Label.new()
	hint.text = "题目按 L01-L20 分级，面向口算练习；整数题答案为正整数，小数题答案为正数。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", COLOR_MUTED_TEXT)
	_apply_font(hint, 18, "font")
	box.add_child(hint)

	var start_button := Button.new()
	start_button.text = "开始战斗"
	start_button.custom_minimum_size = Vector2(0, 56)
	_apply_font(start_button, 24, "font")
	_apply_button_style(start_button)
	start_button.pressed.connect(_request_start_new_game)
	box.add_child(start_button)


func _make_start_section(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_area_style(COLOR_PRIMARY, 0.30))

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	box.add_child(_make_card_header_label(title_text))
	return panel


func _make_card_header_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color", COLOR_MUTED_TEXT)
	_apply_font(label, 15, "font")
	return label


func _make_centered_card_header_label(text: String) -> Label:
	var label := _make_card_header_label(text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_player_cards() -> Control:
	var container := HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 10)

	for i in range(PLAYER_SAVE_COUNT):
		container.add_child(_make_player_card(i))
	return container


func _make_player_card(index: int) -> PanelContainer:
	var selected := index == selected_player_index
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 98)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_player_card_input.bind(index))
	panel.add_theme_stylebox_override("panel", _make_player_card_style(selected))

	var box := VBoxContainer.new()
	box.offset_left = 12
	box.offset_top = 10
	box.offset_right = -12
	box.offset_bottom = -10
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)

	var title := _make_stat_label("存档 %d" % [index + 1], 16, COLOR_SECONDARY if selected else COLOR_MUTED_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var name_edit := LineEdit.new()
	name_edit.text = _get_player_name(index)
	name_edit.placeholder_text = _default_player_name(index)
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.custom_minimum_size = Vector2(0, 36)
	name_edit.editable = selected
	name_edit.mouse_filter = Control.MOUSE_FILTER_STOP if selected else Control.MOUSE_FILTER_IGNORE
	name_edit.focus_exited.connect(_on_player_name_edit_finished.bind(index, name_edit))
	name_edit.text_submitted.connect(_on_player_name_submitted.bind(index, name_edit))
	_apply_player_name_edit_style(name_edit, selected)

	var name_margin := MarginContainer.new()
	name_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_margin.add_theme_constant_override("margin_left", 18)
	name_margin.add_theme_constant_override("margin_right", 18)
	name_margin.add_child(name_edit)
	box.add_child(name_margin)
	return panel


func _make_player_card_style(selected: bool) -> StyleBoxFlat:
	var style := _make_area_style(COLOR_PRIMARY_LIGHT if selected else COLOR_PRIMARY, 0.72 if selected else 0.52)
	style.border_color = COLOR_SECONDARY if selected else COLOR_SECONDARY_DARK
	style.border_color.a = 0.9 if selected else 0.35
	style.set_border_width_all(2 if selected else 1)
	style.set_content_margin_all(0)
	return style


func _make_difficulty_cards() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	difficulty_cards_scroll = scroll
	scroll.custom_minimum_size = Vector2(0, 168)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.gui_input.connect(_on_difficulty_cards_scroll_input.bind(scroll))

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	scroll.add_child(row)

	var history := _load_stats_history()
	for i in range(series_options.size()):
		row.add_child(_make_difficulty_card(i, history))
	call_deferred("_restore_difficulty_cards_scroll", scroll)
	return scroll


func _restore_difficulty_cards_scroll(scroll: ScrollContainer) -> void:
	if is_instance_valid(scroll) and scroll.is_inside_tree():
		scroll.scroll_horizontal = difficulty_cards_scroll_horizontal


func _handle_difficulty_cards_touch_input(event: InputEvent) -> bool:
	if in_battle_screen or not is_instance_valid(difficulty_cards_scroll) or not difficulty_cards_scroll.is_inside_tree():
		return false

	var scroll := difficulty_cards_scroll
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			if not scroll.get_global_rect().has_point(touch_event.position):
				return false
			difficulty_cards_dragging = true
			difficulty_cards_press_position = touch_event.position
			difficulty_cards_press_scroll = scroll.scroll_horizontal
			return true
		if difficulty_cards_dragging:
			_finish_difficulty_cards_input(scroll, touch_event.position)
			return true
	elif event is InputEventScreenDrag:
		if not difficulty_cards_dragging:
			return false
		var drag_event := event as InputEventScreenDrag
		scroll.scroll_horizontal = int(scroll.scroll_horizontal - drag_event.relative.x)
		difficulty_cards_scroll_horizontal = scroll.scroll_horizontal
		return true
	return false


func _on_difficulty_cards_scroll_input(event: InputEvent, scroll: ScrollContainer) -> void:
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		var touch_position := _scroll_input_position_to_viewport(scroll, touch_event.position)
		if touch_event.pressed:
			difficulty_cards_dragging = true
			difficulty_cards_press_position = touch_position
			difficulty_cards_press_scroll = scroll.scroll_horizontal
		else:
			_finish_difficulty_cards_input(scroll, touch_position)
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		scroll.scroll_horizontal = int(scroll.scroll_horizontal - drag_event.relative.x)
		difficulty_cards_scroll_horizontal = scroll.scroll_horizontal
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_position := _scroll_input_position_to_viewport(scroll, mouse_event.position)
			if mouse_event.pressed:
				difficulty_cards_dragging = true
				difficulty_cards_press_position = mouse_position
				difficulty_cards_press_scroll = scroll.scroll_horizontal
			else:
				_finish_difficulty_cards_input(scroll, mouse_position)
	elif event is InputEventMouseMotion and difficulty_cards_dragging:
		var motion_event := event as InputEventMouseMotion
		scroll.scroll_horizontal = int(scroll.scroll_horizontal - motion_event.relative.x)
		difficulty_cards_scroll_horizontal = scroll.scroll_horizontal


func _finish_difficulty_cards_input(scroll: ScrollContainer, release_position: Vector2) -> void:
	if not difficulty_cards_dragging:
		return
	difficulty_cards_dragging = false
	difficulty_cards_scroll_horizontal = scroll.scroll_horizontal
	var moved: float = difficulty_cards_press_position.distance_to(release_position)
	var scrolled: int = abs(difficulty_cards_press_scroll - scroll.scroll_horizontal)
	if moved <= 12.0 and scrolled <= 3:
		var index := _difficulty_card_index_at_position(scroll, release_position)
		if index >= 0:
			call_deferred("_select_difficulty_card", index)


func _scroll_input_position_to_viewport(scroll: ScrollContainer, position: Vector2) -> Vector2:
	return _control_input_position_to_viewport(scroll, position)


func _control_input_position_to_viewport(control: Control, position: Vector2) -> Vector2:
	if control.get_global_rect().has_point(position):
		return position
	return control.get_global_position() + position


func _difficulty_card_index_at_position(scroll: ScrollContainer, position: Vector2) -> int:
	if scroll.get_child_count() == 0:
		return -1
	var row := scroll.get_child(0)
	if not (row is Control):
		return -1
	for i in range(row.get_child_count()):
		var child := row.get_child(i)
		if child is Control:
			var control := child as Control
			if control.get_global_rect().has_point(position):
				return i
	return -1


func _make_difficulty_card(index: int, history: Array) -> PanelContainer:
	var series: Dictionary = series_options[index]
	var selected := index == selected_series_index
	var best_score := _get_best_score_for_series(history, _series_code(series))
	var mastered := best_score > 130
	var difficulty_code := _series_code(series)
	var difficulty_title := _series_title(series)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 168)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.gui_input.connect(_on_difficulty_card_input.bind(panel))
	panel.add_theme_stylebox_override("panel", _make_difficulty_card_style(selected, mastered))

	var box := VBoxContainer.new()
	box.offset_left = 10
	box.offset_top = 8
	box.offset_right = -10
	box.offset_bottom = -8
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var code_label := _make_stat_label(difficulty_code, 18, COLOR_SECONDARY if selected else COLOR_TEXT)
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	code_label.clip_text = true
	code_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(code_label)

	var sprite := TextureRect.new()
	sprite.texture = boss_sprite
	sprite.custom_minimum_size = Vector2(0, 58)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not mastered:
		sprite.material = _make_grayscale_material()
		sprite.modulate.a = 0.72
	box.add_child(sprite)

	var name_label := _make_stat_label(difficulty_title, 13, COLOR_TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	var score_text := "最佳 %d" % best_score if best_score > -99999 else "暂无记录"
	var score_label := _make_stat_label(score_text, 13, COLOR_CORRECT if mastered else COLOR_MUTED_TEXT)
	score_label.custom_minimum_size = Vector2(0, 22)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(score_label)
	return panel


func _make_difficulty_card_style(selected: bool, _mastered: bool) -> StyleBoxFlat:
	var bg := COLOR_PRIMARY_LIGHT if selected else COLOR_PRIMARY
	var style := _make_area_style(bg, 0.78 if selected else 0.56)
	style.border_color = COLOR_SECONDARY if selected else COLOR_SECONDARY_DARK
	style.border_color.a = 0.95 if selected else 0.35
	style.set_border_width_all(2 if selected else 1)
	style.set_content_margin_all(0)
	return style


func _make_grayscale_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(gray), tex.a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _select_difficulty_card(index: int) -> void:
	selected_series_index = index
	_save_player_saves()
	_show_start_screen()


func _on_difficulty_card_input(event: InputEvent, panel: PanelContainer) -> void:
	if not is_instance_valid(difficulty_cards_scroll):
		return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		var touch_position := _control_input_position_to_viewport(panel, touch_event.position)
		if touch_event.pressed:
			difficulty_cards_dragging = true
			difficulty_cards_press_position = touch_position
			difficulty_cards_press_scroll = difficulty_cards_scroll.scroll_horizontal
		else:
			_finish_difficulty_cards_input(difficulty_cards_scroll, touch_position)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_position := _control_input_position_to_viewport(panel, mouse_event.position)
			if mouse_event.pressed:
				difficulty_cards_dragging = true
				difficulty_cards_press_position = mouse_position
				difficulty_cards_press_scroll = difficulty_cards_scroll.scroll_horizontal
			else:
				_finish_difficulty_cards_input(difficulty_cards_scroll, mouse_position)


func _apply_player_name_edit_style(line_edit: LineEdit, selected: bool) -> void:
	_apply_font(line_edit, 17, "font")
	line_edit.add_theme_color_override("font_color", COLOR_TEXT if selected else COLOR_MUTED_TEXT)
	line_edit.add_theme_color_override("font_uneditable_color", COLOR_MUTED_TEXT)
	line_edit.add_theme_color_override("font_placeholder_color", COLOR_MUTED_TEXT)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PRIMARY
	style.bg_color.a = 0.44 if selected else 0.22
	style.set_border_width_all(0)
	style.border_width_bottom = 1
	style.border_color = COLOR_SECONDARY if selected else COLOR_SECONDARY_DARK
	style.border_color.a = 0.95 if selected else 0.55
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 0
	style.content_margin_bottom = 3
	line_edit.add_theme_stylebox_override("normal", style)
	line_edit.add_theme_stylebox_override("read_only", style)
	line_edit.add_theme_stylebox_override("focus", style)


func _make_header_icon_button(icon_texture: Texture2D, tooltip: String) -> Button:
	var button := Button.new()
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(56, 56)
	_apply_button_style(button)

	_add_centered_button_icon(button, icon_texture, 28)
	return button


func _add_centered_button_icon(button: Button, icon_texture: Texture2D, icon_size: int) -> void:
	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.anchor_left = 0.5
	icon.anchor_top = 0.5
	icon.anchor_right = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -icon_size * 0.5
	icon.offset_top = -icon_size * 0.5
	icon.offset_right = icon_size * 0.5
	icon.offset_bottom = icon_size * 0.5
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = COLOR_TEXT
	button.add_child(icon)


func _is_portrait_layout() -> bool:
	var browser_size := _get_browser_window_size()
	if browser_size.x > 0 and browser_size.y > 0:
		return browser_size.y > browser_size.x or browser_size.x < PORTRAIT_BREAKPOINT
	var size := Vector2(DisplayServer.window_get_size())
	if size.x <= 0 or size.y <= 0:
		size = get_viewport_rect().size
	return size.y > size.x or size.x < PORTRAIT_BREAKPOINT


func _get_browser_window_size() -> Vector2:
	if not OS.has_feature("web"):
		return Vector2.ZERO
	var width = JavaScriptBridge.eval("window.innerWidth", true)
	var height = JavaScriptBridge.eval("window.innerHeight", true)
	if typeof(width) != TYPE_FLOAT and typeof(width) != TYPE_INT:
		return Vector2.ZERO
	if typeof(height) != TYPE_FLOAT and typeof(height) != TYPE_INT:
		return Vector2.ZERO
	return Vector2(float(width), float(height))


func _set_header_button_icon(button: Button, icon_texture: Texture2D) -> void:
	for child in button.get_children():
		if child is TextureRect:
			child.texture = icon_texture
			return


func _toggle_skin() -> void:
	dark_skin_enabled = not dark_skin_enabled
	_apply_skin_palette()
	_apply_theme()
	_request_show_start_screen()


func _apply_skin_palette() -> void:
	if dark_skin_enabled:
		COLOR_BACKGROUND = Color("#201914")
		COLOR_PRIMARY = Color("#34271b")
		COLOR_PRIMARY_LIGHT = Color("#403120")
		COLOR_SECONDARY = Color("#e3b666")
		COLOR_SECONDARY_DARK = Color("#8a6a3b")
		COLOR_TEXT = Color("#fff4df")
		COLOR_MUTED_TEXT = Color("#d7c3a1")
		COLOR_HEALTH = Color("#e0a847")
		COLOR_STATE = Color("#d7c3a1")
		COLOR_BUTTON = Color("#33271b")
		COLOR_BUTTON_ACTIVE = Color("#5b431f")
		COLOR_CORRECT = Color("#62c978")
		COLOR_WRONG = Color("#e46f61")
	else:
		COLOR_BACKGROUND = Color("#eee2c8")
		COLOR_PRIMARY = Color("#fff8e8")
		COLOR_PRIMARY_LIGHT = Color("#fff8e8")
		COLOR_SECONDARY = Color("#b9822f")
		COLOR_SECONDARY_DARK = Color("#c9b58a")
		COLOR_TEXT = Color("#2b2418")
		COLOR_MUTED_TEXT = Color("#5f513e")
		COLOR_HEALTH = Color("#c9963f")
		COLOR_STATE = Color("#5f513e")
		COLOR_BUTTON = Color("#fff8e8")
		COLOR_BUTTON_ACTIVE = Color("#f4e5bd")
		COLOR_CORRECT = Color("#2e9d50")
		COLOR_WRONG = Color("#c0392b")


func _load_icons() -> void:
	icon_pause = _load_icon(ICON_PAUSE_PATH)
	icon_play = _load_icon(ICON_PLAY_PATH)
	icon_back = _load_icon(ICON_BACK_PATH)
	icon_retry = _load_icon(ICON_RETRY_PATH)
	icon_home = _load_icon(ICON_HOME_PATH)
	icon_eraser = _load_icon(ICON_ERASER_PATH)
	icon_dark_theme = _load_icon(ICON_DARK_THEME_PATH)


func _load_sprites() -> void:
	player_sprite = _load_icon(PLAYER_SPRITE_PATH)
	boss_sprite = _load_icon(BOSS_SPRITE_PATH)


func _load_font() -> void:
	ui_font = load(UI_FONT_PATH) as Font
	if ui_font == null:
		push_error("Failed to load UI font: %s" % UI_FONT_PATH)


func _load_icon(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("Failed to load icon: %s" % path)
	return texture


func _load_player_saves() -> void:
	if not FileAccess.file_exists(PLAYER_SAVES_FILE_PATH):
		selected_user = _get_player_name(selected_player_index)
		return
	var file := FileAccess.open(PLAYER_SAVES_FILE_PATH, FileAccess.READ)
	if file == null:
		push_warning("无法读取玩家存档：%s" % PLAYER_SAVES_FILE_PATH)
		selected_user = _get_player_name(selected_player_index)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("玩家存档格式无效：%s" % PLAYER_SAVES_FILE_PATH)
		selected_user = _get_player_name(selected_player_index)
		return
	var data: Dictionary = parsed
	var names: Variant = data.get("player_names", [])
	if names is Array:
		for i in range(min(PLAYER_SAVE_COUNT, names.size())):
			var name := str(names[i]).strip_edges()
			player_names[i] = name if not name.is_empty() else _default_player_name(i)
	_ensure_unique_player_names()
	selected_player_index = clamp(int(data.get("selected_player_index", selected_player_index)), 0, PLAYER_SAVE_COUNT - 1)
	selected_series_index = clamp(int(data.get("selected_series_index", selected_series_index)), 0, series_options.size() - 1)
	selected_user = _get_player_name(selected_player_index)


func _save_player_saves() -> void:
	var file := FileAccess.open(PLAYER_SAVES_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("无法保存玩家存档：%s" % PLAYER_SAVES_FILE_PATH)
		return
	file.store_string(JSON.stringify({
		"player_names": player_names,
		"selected_player_index": selected_player_index,
		"selected_series_index": selected_series_index
	}, "\t"))


func _default_player_name(index: int) -> String:
	return "玩家%d" % [index + 1]


func _get_player_name(index: int) -> String:
	var name := str(player_names[index]).strip_edges()
	return name if not name.is_empty() else _default_player_name(index)


func _ensure_unique_player_names() -> void:
	var used := {}
	for i in range(PLAYER_SAVE_COUNT):
		var name := _get_player_name(i)
		if used.has(name):
			name = _first_available_default_player_name(used)
		player_names[i] = name
		used[name] = true


func _first_available_default_player_name(used: Dictionary) -> String:
	for i in range(PLAYER_SAVE_COUNT):
		var name := _default_player_name(i)
		if not used.has(name):
			return name
	var suffix := PLAYER_SAVE_COUNT + 1
	while used.has("玩家%d" % suffix):
		suffix += 1
	return "玩家%d" % suffix


func _has_duplicate_player_name(name: String, current_index: int) -> bool:
	for i in range(PLAYER_SAVE_COUNT):
		if i != current_index and _get_player_name(i) == name:
			return true
	return false


func _on_player_name_submitted(_text: String, index: int, name_edit: LineEdit) -> void:
	_commit_player_name(index, name_edit)


func _on_player_name_edit_finished(index: int, name_edit: LineEdit) -> void:
	_commit_player_name(index, name_edit)


func _commit_player_name(index: int, name_edit: LineEdit) -> void:
	var name := name_edit.text.strip_edges()
	if name.is_empty():
		name = _default_player_name(index)
		name_edit.text = name
	if _has_duplicate_player_name(name, index):
		name = _get_player_name(index)
		name_edit.text = name
	player_names[index] = name
	if index == selected_player_index:
		selected_user = name
	_save_player_saves()


func _select_player_card(index: int) -> void:
	selected_player_index = index
	selected_user = _get_player_name(index)
	_save_player_saves()
	_show_start_screen()


func _request_show_start_screen() -> void:
	call_deferred("_show_start_screen")


func _request_start_new_game() -> void:
	call_deferred("_start_new_game")


func _on_player_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			call_deferred("_select_player_card", index)


func _on_series_selected(index: int) -> void:
	selected_series_index = index
	_save_player_saves()


func _build_battle_ui() -> void:
	_clear_screen()
	keypad_buttons.clear()

	var portrait_layout := _is_portrait_layout()
	in_battle_screen = true
	current_battle_portrait_layout = portrait_layout
	var viewport_size := get_viewport().get_visible_rect().size
	var frame_height: float = max(0.0, viewport_size.y - BATTLE_FRAME_MARGIN * 2.0)
	var available_content_height: float = max(0.0, frame_height - BATTLE_FRAME_PADDING * 2.0)
	var header_height := 56.0
	var header_board_gap := 18.0
	var natural_board_height: float = COMBATANT_PANEL_HEIGHT * 2.0 + QUESTION_PANEL_HEIGHT + BATTLE_BOARD_GAP * 2.0
	var available_board_height: float = max(0.0, available_content_height - header_height - header_board_gap)
	var vertical_scale: float = min(1.0, available_board_height / natural_board_height) if not portrait_layout else 1.0
	var min_combatant_panel_height: float = AVATAR_SIZE + PANEL_PADDING * 2.0
	var combatant_panel_height: float = max(min_combatant_panel_height, floor(COMBATANT_PANEL_HEIGHT * vertical_scale))
	var log_panel_height: float = combatant_panel_height
	var question_panel_height: float = max(160.0, floor(available_board_height - combatant_panel_height * 2.0 - BATTLE_BOARD_GAP * 2.0))
	var submit_panel_height: float = combatant_panel_height
	var keypad_panel_height: float = question_panel_height + BATTLE_BOARD_GAP + submit_panel_height
	var question_stack_height: float = max(80.0, question_panel_height - PANEL_PADDING * 2.0)
	var keypad_controls_height: float = KEYPAD_ANSWER_HEIGHT + KEYPAD_INNER_PADDING * 2.0 + KEYPAD_KEY_HEIGHT * 4.0 + KEYPAD_KEY_GAP * 3.0
	var keypad_scale: float = min(1.0, question_panel_height / keypad_controls_height) if not portrait_layout else 1.0
	var keypad_answer_height: float = max(44.0, floor(KEYPAD_ANSWER_HEIGHT * keypad_scale))
	var keypad_key_height: float = max(38.0, floor(KEYPAD_KEY_HEIGHT * keypad_scale))
	var keypad_key_gap: int = int(max(4.0, floor(KEYPAD_KEY_GAP * keypad_scale)))
	var keypad_font_size: int = int(max(22.0, floor(28.0 * keypad_scale)))
	var answer_font_size: int = int(max(28.0, floor(42.0 * keypad_scale)))
	var submit_title_font_size: int = int(max(22.0, floor(28.0 * keypad_scale)))
	var submit_hint_font_size: int = int(max(13.0, floor(17.0 * keypad_scale)))

	var frame := PanelContainer.new()
	frame.anchor_right = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = BATTLE_FRAME_MARGIN
	frame.offset_top = BATTLE_FRAME_MARGIN
	frame.offset_right = -BATTLE_FRAME_MARGIN
	frame.offset_bottom = -BATTLE_FRAME_MARGIN
	frame.add_theme_stylebox_override("panel", _make_battle_frame_style())
	screen_root.add_child(frame)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 18)
	frame.add_child(root)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 56)
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var header_left_spacer := Control.new()
	header_left_spacer.custom_minimum_size = Vector2(120, 0)
	header.add_child(header_left_spacer)

	title_label = Label.new()
	title_label.text = GAME_DISPLAY_NAME
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_color_override("font_color", COLOR_SECONDARY)
	_apply_font(title_label, 32, "font")
	header.add_child(title_label)

	var header_actions := HBoxContainer.new()
	header_actions.custom_minimum_size = Vector2(120, 0)
	header_actions.alignment = BoxContainer.ALIGNMENT_END
	header_actions.add_theme_constant_override("separation", 8)
	header.add_child(header_actions)

	pause_button = _make_header_icon_button(icon_pause, "暂停")
	pause_button.pressed.connect(_toggle_pause)
	header_actions.add_child(pause_button)

	exit_button = _make_header_icon_button(icon_back, "退出")
	exit_button.pressed.connect(_exit_battle)
	header_actions.add_child(exit_button)

	feedback_label = Label.new()
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_color_override("font_color", COLOR_STATE)
	_apply_font(feedback_label, 18, "font")

	var board = VBoxContainer.new() if portrait_layout else HBoxContainer.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("separation", BATTLE_BOARD_GAP)
	root.add_child(board)

	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", BATTLE_BOARD_GAP)
	board.add_child(left_column)

	var right_column := VBoxContainer.new()
	right_column.custom_minimum_size = Vector2(RIGHT_COLUMN_WIDTH, 0)
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", BATTLE_BOARD_GAP)
	if not portrait_layout:
		board.add_child(right_column)

	var combatant_height: float = COMBATANT_PANEL_HEIGHT_PORTRAIT if portrait_layout else combatant_panel_height

	var boss_panel := _make_combatant_panel("Boss", "大黄蜂", false)
	boss_panel.custom_minimum_size = Vector2(0, combatant_height)
	boss_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left_column.add_child(boss_panel)

	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size = Vector2(0, LOG_PANEL_HEIGHT if portrait_layout else log_panel_height)
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	log_panel.add_theme_stylebox_override("panel", _make_area_style(COLOR_PRIMARY, 0.30))
	if not portrait_layout:
		right_column.add_child(log_panel)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = false
	log_label.scroll_active = true
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_color_override("default_color", COLOR_TEXT)
	log_label.add_theme_color_override("font_color", COLOR_TEXT)
	_apply_font(log_label, 14, "normal_font")
	_apply_font(log_label, 14, "bold_font")
	log_panel.add_child(log_label)

	var question_panel := PanelContainer.new()
	question_panel.custom_minimum_size = Vector2(0, QUESTION_PANEL_HEIGHT_PORTRAIT if portrait_layout else question_panel_height)
	question_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	question_panel.add_theme_stylebox_override("panel", _make_area_style(COLOR_PRIMARY, 0.28))
	left_column.add_child(question_panel)

	var question_box := VBoxContainer.new()
	question_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	question_box.add_theme_constant_override("separation", 12)
	question_panel.add_child(question_box)

	question_stack = Control.new()
	question_stack.custom_minimum_size = Vector2(0, QUESTION_STACK_HEIGHT_PORTRAIT if portrait_layout else question_stack_height)
	question_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	question_stack.clip_contents = true
	question_box.add_child(question_stack)

	previous_question_label = _make_question_label(24, COLOR_MUTED_TEXT, 0.0)
	question_stack.add_child(previous_question_label)

	current_question_label = _make_question_label(48 if portrait_layout else 62, COLOR_TEXT, 1.0)
	question_stack.add_child(current_question_label)

	next_question_label = _make_question_label(24, COLOR_MUTED_TEXT, 0.0)
	question_stack.add_child(next_question_label)

	question_pause_overlay = PanelContainer.new()
	question_pause_overlay.anchor_right = 1.0
	question_pause_overlay.anchor_bottom = 1.0
	question_pause_overlay.visible = false
	question_pause_overlay.add_theme_stylebox_override("panel", _make_area_style(COLOR_BACKGROUND, 0.9))
	question_stack.add_child(question_pause_overlay)

	var pause_overlay_label := Label.new()
	pause_overlay_label.text = "暂停中"
	pause_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_overlay_label.anchor_right = 1.0
	pause_overlay_label.anchor_bottom = 1.0
	pause_overlay_label.add_theme_color_override("font_color", COLOR_SECONDARY)
	_apply_font(pause_overlay_label, 34, "font")
	question_pause_overlay.add_child(pause_overlay_label)

	var keypad_panel := PanelContainer.new()
	keypad_panel.custom_minimum_size = Vector2(0, KEYPAD_PANEL_HEIGHT if portrait_layout else keypad_panel_height)
	keypad_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keypad_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	keypad_panel.add_theme_stylebox_override("panel", _make_keypad_panel_style())
	if not portrait_layout:
		right_column.add_child(keypad_panel)

	var keypad_box := VBoxContainer.new()
	keypad_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keypad_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	keypad_box.add_theme_constant_override("separation", 0)
	keypad_panel.add_child(keypad_box)

	var keypad_controls := VBoxContainer.new()
	keypad_controls.custom_minimum_size = Vector2(0, QUESTION_PANEL_HEIGHT_PORTRAIT if portrait_layout else question_panel_height)
	keypad_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keypad_controls.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	keypad_controls.add_theme_constant_override("separation", 0)
	keypad_box.add_child(keypad_controls)

	answer_display = Label.new()
	answer_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	answer_display.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	answer_display.custom_minimum_size = Vector2(0, keypad_answer_height)
	answer_display.add_theme_color_override("font_color", COLOR_TEXT)
	answer_display.add_theme_stylebox_override("normal", _make_answer_display_style())
	_apply_font(answer_display, answer_font_size, "font")
	keypad_controls.add_child(answer_display)

	var keys_wrapper := PanelContainer.new()
	keys_wrapper.add_theme_stylebox_override("panel", _make_keys_wrapper_style())
	keypad_controls.add_child(keys_wrapper)

	var keypad := GridContainer.new()
	keypad.columns = 3
	keypad.add_theme_constant_override("hseparation", keypad_key_gap)
	keypad.add_theme_constant_override("vseparation", keypad_key_gap)
	keys_wrapper.add_child(keypad)

	var keypad_values := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", ".", "清空"]
	for value in keypad_values:
		var button := Button.new()
		button.text = value
		button.custom_minimum_size = Vector2(0, keypad_key_height)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if value == "清空":
			button.text = ""
			button.tooltip_text = "清空"
			_add_centered_button_icon(button, icon_eraser, 28)
		_apply_font(button, keypad_font_size, "font")
		_apply_button_style(button)
		button.pressed.connect(_on_keypad_pressed.bind(value))
		keypad_buttons.append(button)
		keypad.add_child(button)

	var keypad_submit_spacer := Control.new()
	keypad_submit_spacer.custom_minimum_size = Vector2(0, BATTLE_BOARD_GAP if not portrait_layout else 0)
	keypad_submit_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keypad_submit_spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	keypad_box.add_child(keypad_submit_spacer)

	var submit_wrapper := MarginContainer.new()
	submit_wrapper.custom_minimum_size = Vector2(0, COMBATANT_PANEL_HEIGHT_PORTRAIT if portrait_layout else submit_panel_height)
	submit_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	submit_wrapper.add_theme_constant_override("margin_left", 0)
	submit_wrapper.add_theme_constant_override("margin_right", 0)
	submit_wrapper.add_theme_constant_override("margin_top", 0)
	submit_wrapper.add_theme_constant_override("margin_bottom", 0)
	submit_wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	keypad_box.add_child(submit_wrapper)

	var submit_area := PanelContainer.new()
	submit_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	submit_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	submit_area.mouse_filter = Control.MOUSE_FILTER_STOP
	submit_area.gui_input.connect(_on_keypad_panel_input)
	submit_area.add_theme_stylebox_override("panel", _make_submit_area_style())
	submit_wrapper.add_child(submit_area)

	var submit_hint_box := VBoxContainer.new()
	submit_hint_box.anchor_right = 1.0
	submit_hint_box.anchor_bottom = 1.0
	submit_hint_box.alignment = BoxContainer.ALIGNMENT_CENTER
	submit_hint_box.add_theme_constant_override("separation", 8)
	submit_area.add_child(submit_hint_box)

	submit_hint_label = Label.new()
	submit_hint_label.text = "提交答案"
	submit_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	submit_hint_label.add_theme_color_override("font_color", COLOR_SECONDARY)
	_apply_font(submit_hint_label, submit_title_font_size, "font")
	submit_hint_box.add_child(submit_hint_label)

	submit_hint_sub_label = Label.new()
	submit_hint_sub_label.text = "点击此空白区域提交"
	submit_hint_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	submit_hint_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	submit_hint_sub_label.add_theme_color_override("font_color", COLOR_MUTED_TEXT)
	_apply_font(submit_hint_sub_label, submit_hint_font_size, "font")
	submit_hint_box.add_child(submit_hint_sub_label)

	var player_panel := _make_combatant_panel("玩家", "小骑士", true)
	player_panel.custom_minimum_size = Vector2(0, combatant_height)
	player_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if portrait_layout:
		left_column.add_child(player_panel)
		left_column.add_child(log_panel)
		left_column.add_child(keypad_panel)
	else:
		left_column.add_child(player_panel)


func _make_combatant_panel(_title: String, subtitle: String, is_player: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_area_style(COLOR_PRIMARY, 0.30))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.add_theme_stylebox_override("panel", _make_portrait_style())
	row.add_child(portrait)

	var sprite := player_sprite if is_player else boss_sprite
	if sprite != null:
		var portrait_image := TextureRect.new()
		portrait_image.texture = sprite
		portrait_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.add_child(portrait_image)
	else:
		var portrait_label := Label.new()
		portrait_label.text = "◢◣\n◥◤"
		portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		portrait_label.add_theme_color_override("font_color", COLOR_TEXT)
		_apply_font(portrait_label, 28, "font")
		portrait.add_child(portrait_label)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 18)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = subtitle
	name_label.add_theme_color_override("font_color", COLOR_SECONDARY)
	_apply_font(name_label, 26, "font")
	info.add_child(name_label)

	var hp_box := Control.new()
	hp_box.custom_minimum_size = Vector2(0, 28)
	hp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(hp_box)

	var hp_bar := ProgressBar.new()
	hp_bar.anchor_right = 1.0
	hp_bar.anchor_bottom = 1.0
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("background", _make_health_bar_background_style())
	hp_bar.add_theme_stylebox_override("fill", _make_health_bar_fill_style())
	hp_box.add_child(hp_bar)

	var hp_label := Label.new()
	hp_label.anchor_right = 1.0
	hp_label.anchor_bottom = 1.0
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_color_override("font_color", COLOR_TEXT)
	_apply_font(hp_label, 18, "font")
	hp_box.add_child(hp_label)

	if is_player:
		player_hp_label = hp_label
		player_hp_bar = hp_bar
	else:
		boss_hp_label = hp_label
		boss_hp_bar = hp_bar
	return panel


func _make_question_label(font_size: int, color: Color, alpha: float) -> Label:
	var label := Label.new()
	label.anchor_right = 1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_color_override("font_color", color)
	_apply_font(label, font_size, "font")
	label.modulate.a = alpha
	return label


func _make_panel_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func _make_area_style(color: Color, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	color.a = alpha
	style.bg_color = color
	style.border_color = COLOR_SECONDARY_DARK
	style.border_color.a = 0.92
	style.set_border_width_all(1)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.set_content_margin_all(PANEL_PADDING)
	return style


func _make_battle_frame_style() -> StyleBoxFlat:
	var style := _make_panel_style(COLOR_BACKGROUND, COLOR_SECONDARY_DARK, 1)
	style.bg_color.a = 1.0
	style.border_color.a = 0.7
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.set_content_margin_all(BATTLE_FRAME_PADDING)
	return style


func _make_portrait_style() -> StyleBoxFlat:
	var style := _make_panel_style(COLOR_PRIMARY, Color("#5f5f5f"), 1)
	style.bg_color.a = 0.0
	style.border_color.a = 0.9
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.set_content_margin_all(UI_PADDING_MEDIUM)
	return style


func _make_health_bar_background_style() -> StyleBoxFlat:
	var style := _make_area_style(COLOR_PRIMARY, 0.22)
	style.set_content_margin_all(0)
	return style


func _make_health_bar_fill_style() -> StyleBoxFlat:
	var style := _make_area_style(COLOR_HEALTH, 0.95)
	style.set_content_margin_all(0)
	return style


func _make_submit_area_style() -> StyleBoxFlat:
	var style := _make_panel_style(COLOR_SECONDARY, COLOR_SECONDARY, 1)
	style.bg_color.a = 0.14
	style.border_color.a = 0.0
	style.set_border_width_all(0)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.set_content_margin_all(20)
	return style


func _make_keypad_panel_style() -> StyleBoxFlat:
	var style := _make_area_style(COLOR_PRIMARY, 0.30)
	style.set_content_margin_all(0)
	return style


func _make_answer_display_style() -> StyleBoxFlat:
	var style := _make_area_style(COLOR_PRIMARY, 0.22)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.border_color.a = 0.6
	style.set_border_width_all(0)
	style.border_width_bottom = 1
	style.set_content_margin_all(0)
	return style


func _make_keys_wrapper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(0)
	style.set_content_margin_all(KEYPAD_INNER_PADDING)
	return style


func _make_button_style(is_active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BUTTON_ACTIVE if is_active else COLOR_BUTTON
	style.bg_color.a = 0.92 if is_active else 0.34
	style.border_color = COLOR_SECONDARY if is_active else COLOR_SECONDARY_DARK
	style.border_color.a = 0.95
	style.set_border_width_all(2 if is_active else 1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.set_content_margin_all(UI_PADDING_SMALL)
	return style


func _apply_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(false))
	button.add_theme_stylebox_override("hover", _make_button_style(true))
	button.add_theme_stylebox_override("pressed", _make_button_style(true))
	button.add_theme_stylebox_override("focus", _make_button_style(true))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	button.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	button.add_theme_color_override("font_focus_color", COLOR_TEXT)
	button.add_theme_color_override("font_disabled_color", COLOR_MUTED_TEXT)


func _apply_theme() -> void:
	if ui_font != null:
		var ui_theme := Theme.new()
		ui_theme.default_font = ui_font
		ui_theme.default_font_size = 16
		ui_theme.set_font("font", "TooltipLabel", ui_font)
		ui_theme.set_font_size("font_size", "TooltipLabel", 16)
		theme = ui_theme

	var panel := StyleBoxFlat.new()
	panel.bg_color = COLOR_BACKGROUND
	panel.set_border_width_all(0)
	add_theme_stylebox_override("panel", panel)
	if background_rect != null:
		background_rect.color = COLOR_BACKGROUND


func _apply_font(control: Control, size: int, theme_name: String = "font") -> void:
	control.add_theme_font_override(theme_name, _make_font(size))
	var size_name := "font_size"
	if theme_name.ends_with("_font"):
		size_name = theme_name + "_size"
	control.add_theme_font_size_override(size_name, size)


func _make_font(_size: int) -> Font:
	if ui_font != null:
		return ui_font
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Maple Mono NF CN", "Microsoft YaHei UI", "Microsoft YaHei", "Arial"])
	return font


func _start_new_game() -> void:
	selected_user = _get_player_name(selected_player_index)
	_build_battle_ui()
	boss_max_hp = _get_boss_max_hp()
	player_hp = PLAYER_MAX_HP
	boss_hp = boss_max_hp
	current_count = 0
	round_index = 0
	game_over = false
	is_paused = false
	correct_count = 0
	wrong_count = 0
	total_valid_duration = 0.0
	min_duration = 0.0
	max_duration = 0.0
	max_streak_count = 0
	correct_records.clear()
	answer_records.clear()
	current_stats_saved = false
	question_accumulated_msec = 0
	previous_problem = {}
	generated_question_texts.clear()
	current_problem = _generate_problem_with_constraints(1, null)
	next_problem = _generate_problem_with_constraints(2, current_problem["answer"])
	log_label.text = ""
	var series: Dictionary = series_options[selected_series_index]
	feedback_label.text = "当前系列：%s。答对计入有效时间，答错不计入题数和时间。" % _series_display_name(series)
	_log("开始 %s，Boss %dHP" % [_series_code(series), boss_max_hp])
	_advance_to_current_problem(false)
	_update_ui()
	call_deferred("_refresh_current_question_layout")


func _get_boss_max_hp() -> int:
	var override_value := _get_boss_hp_override()
	if override_value.is_valid_int():
		var boss_hp_value: int = int(override_value)
		return boss_hp_value if boss_hp_value > 0 else 1
	return BOSS_MAX_HP


func _get_boss_hp_override() -> String:
	if OS.has_feature("web"):
		var value = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('%s') || ''" % BOSS_HP_ENV, true)
		if typeof(value) == TYPE_STRING:
			return str(value)
	if OS.has_environment(BOSS_HP_ENV):
		return OS.get_environment(BOSS_HP_ENV)
	return ""


func _toggle_pause() -> void:
	if game_over:
		return

	is_paused = not is_paused
	if is_paused:
		question_accumulated_msec += Time.get_ticks_msec() - question_started_msec
		_set_header_button_icon(pause_button, icon_play)
		question_pause_overlay.visible = true
		feedback_label.text = "已暂停。"
		_log("暂停")
	else:
		question_started_msec = Time.get_ticks_msec()
		_set_header_button_icon(pause_button, icon_pause)
		question_pause_overlay.visible = false
		feedback_label.text = "继续答题。"
		_log("继续")
	_update_ui()


func _exit_battle() -> void:
	game_over = true
	_request_show_start_screen()


func _rebuild_battle_ui_if_layout_changed() -> void:
	if not in_battle_screen:
		return
	var portrait_layout := _is_portrait_layout()
	if portrait_layout == current_battle_portrait_layout:
		return
	var feedback_text := feedback_label.text if is_instance_valid(feedback_label) else ""
	var log_text := log_label.text if is_instance_valid(log_label) else ""
	_build_battle_ui()
	if is_instance_valid(log_label):
		log_label.text = log_text
	if is_instance_valid(feedback_label):
		feedback_label.text = feedback_text
	_update_question_stack(false)
	_update_answer_display()
	_update_ui()
	if is_instance_valid(question_pause_overlay):
		question_pause_overlay.visible = is_paused
	if is_instance_valid(pause_button):
		_set_header_button_icon(pause_button, icon_play if is_paused else icon_pause)


func _next_question() -> void:
	previous_problem = current_problem
	current_problem = next_problem
	next_problem = _generate_problem_with_constraints(round_index + 2, current_problem["answer"])
	_advance_to_current_problem(true)


func _advance_to_current_problem(animate: bool) -> void:
	round_index += 1
	current_answer = float(current_problem["answer"])
	question_started_msec = Time.get_ticks_msec()
	question_accumulated_msec = 0
	answer_text = ""
	_update_question_stack(animate)
	_update_answer_display()
	_update_ui()


func _update_question_stack(animate: bool) -> void:
	previous_question_label.text = previous_problem["text"] if previous_problem.has("text") else ""
	current_question_label.text = current_problem["text"]
	next_question_label.text = next_problem["text"] if next_problem.has("text") else ""
	var stack_height: float = max(question_stack.size.y, question_stack.custom_minimum_size.y)
	var small_height: float = 42.0
	var current_height: float = min(120.0, max(86.0, stack_height * 0.5))
	var previous_y: float = 6.0
	var current_y: float = max(0.0, (stack_height - current_height) * 0.5)
	var next_y: float = max(0.0, stack_height - small_height - 6.0)

	if question_tween != null and question_tween.is_valid():
		question_tween.kill()

	if animate:
		question_tween = create_tween()
		question_tween.set_parallel(true)
		_place_question_label(previous_question_label, current_y, small_height)
		_place_question_label(current_question_label, next_y, current_height)
		_place_question_label(next_question_label, next_y + small_height, small_height)
		previous_question_label.modulate.a = 0.9 if previous_problem.has("text") else 0.0
		current_question_label.modulate.a = 0.45
		next_question_label.modulate.a = 0.0
		_tween_question_label(previous_question_label, previous_y, 0.45 if previous_problem.has("text") else 0.0)
		_tween_question_label(current_question_label, current_y, 1.0)
		_tween_question_label(next_question_label, next_y, 0.45 if next_problem.has("text") else 0.0)
	else:
		_place_question_label(previous_question_label, previous_y, small_height)
		_place_question_label(current_question_label, current_y, current_height)
		_place_question_label(next_question_label, next_y, small_height)
		previous_question_label.modulate.a = 0.45 if previous_problem.has("text") else 0.0
		current_question_label.modulate.a = 1.0
		next_question_label.modulate.a = 0.45 if next_problem.has("text") else 0.0


func _place_question_label(label: Label, y: float, height: float) -> void:
	label.offset_left = 0
	label.offset_top = y
	label.offset_right = 0
	label.offset_bottom = y + height


func _refresh_current_question_layout() -> void:
	if in_battle_screen and is_instance_valid(question_stack):
		_update_question_stack(false)


func _tween_question_label(label: Label, target_y: float, target_alpha: float) -> void:
	question_tween.tween_property(label, "position", Vector2(0, target_y), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	question_tween.tween_property(label, "modulate:a", target_alpha, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _generate_problem(question_number: int) -> Dictionary:
	var series: Dictionary = series_options[selected_series_index]
	var op: String = series["op"]

	if op == "make_five":
		var b := rng.randi_range(1, 4)
		return _make_problem(5, b, "-", 5 - b, question_number)
	if op == "make_ten":
		var b := rng.randi_range(1, 9)
		return _make_problem(10, b, "-", 10 - b, question_number)
	if op == "one_add_one_no_carry":
		var a := rng.randi_range(1, 8)
		var b := rng.randi_range(1, 9 - a)
		return _make_problem(a, b, "+", a + b, question_number)
	if op == "one_add_one_carry":
		var a := rng.randi_range(2, 9)
		var b := rng.randi_range(10 - a, 9)
		return _make_problem(a, b, "+", a + b, question_number)
	if op == "one_sub_one":
		var a := rng.randi_range(2, 9)
		var b := rng.randi_range(1, a - 1)
		return _make_problem(a, b, "-", a - b, question_number)
	if op == "two_add_one":
		var a := _number_for_digits(2)
		var b := _number_for_digits(1)
		return _make_problem(a, b, "+", a + b, question_number)
	if op == "two_sub_one_no_borrow":
		var ones := rng.randi_range(1, 9)
		var tens := rng.randi_range(1, 9)
		var a := tens * 10 + ones
		var b := rng.randi_range(1, ones)
		return _make_problem(a, b, "-", a - b, question_number)
	if op == "two_sub_one_borrow":
		var ones := rng.randi_range(0, 8)
		var tens := rng.randi_range(1, 9)
		var a := tens * 10 + ones
		var b := rng.randi_range(ones + 1, 9)
		return _make_problem(a, b, "-", a - b, question_number)
	if op == "two_add_two":
		var a := _number_for_digits(2)
		var b := _number_for_digits(2)
		return _make_problem(a, b, "+", a + b, question_number)
	if op == "two_sub_two":
		var a := rng.randi_range(11, 99)
		var b := rng.randi_range(10, a - 1)
		return _make_problem(a, b, "-", a - b, question_number)
	if op == "times_table_multiply":
		var a := _number_for_digits(1)
		var b := _number_for_digits(1)
		return _make_problem(a, b, "x", a * b, question_number)
	if op == "times_table_divide":
		var answer := _number_for_digits(1)
		var b := _number_for_digits(1)
		return _make_problem(answer * b, b, "/", answer, question_number)
	if op == "two_multiply_one":
		var a := _number_for_digits(2)
		var b := _number_for_digits(1)
		return _make_problem(a, b, "x", a * b, question_number)
	if op == "one_digit_remainder":
		var b := rng.randi_range(2, 9)
		var quotient := rng.randi_range(1, 9)
		var remainder := rng.randi_range(1, b - 1)
		var a := quotient * b + remainder
		return _make_remainder_problem(a, b, remainder, question_number)
	if op == "one_decimal_add":
		var a := _decimal_value(1)
		var b := _decimal_value(1)
		return _make_decimal_problem(a, b, "+", _round_decimal(a + b, 1), 1, question_number)
	if op == "one_decimal_sub":
		var values := _decimal_sub_values(1)
		var a: float = values[0]
		var b: float = values[1]
		return _make_decimal_problem(a, b, "-", _round_decimal(a - b, 1), 1, question_number)
	if op == "two_decimal_add":
		var a := _decimal_value(2)
		var b := _decimal_value(2)
		return _make_decimal_problem(a, b, "+", _round_decimal(a + b, 2), 2, question_number)
	if op == "two_decimal_sub":
		var values := _decimal_sub_values(2)
		var a: float = values[0]
		var b: float = values[1]
		return _make_decimal_problem(a, b, "-", _round_decimal(a - b, 2), 2, question_number)
	if op == "gcd":
		var a := rng.randi_range(2, 99)
		var b := rng.randi_range(2, 99)
		return _make_group_problem(a, b, "(", ")", _gcd(a, b), question_number)
	var a := rng.randi_range(1, 99)
	var b := rng.randi_range(1, 99)
	return _make_group_problem(a, b, "[", "]", _lcm(a, b), question_number)


func _generate_problem_with_constraints(question_number: int, previous_answer) -> Dictionary:
	var allow_duplicate_question := _can_repeat_question_for_current_series()
	var fallback := _generate_problem(question_number)
	if _problem_matches_constraints(fallback, previous_answer, allow_duplicate_question):
		_remember_generated_question(fallback)
		return fallback
	for i in range(300):
		var candidate := _generate_problem(question_number)
		if _problem_matches_constraints(candidate, previous_answer, allow_duplicate_question):
			_remember_generated_question(candidate)
			return candidate
	_remember_generated_question(fallback)
	return fallback


func _problem_matches_constraints(problem: Dictionary, previous_answer, allow_duplicate_question: bool) -> bool:
	if previous_answer != null and _same_answer_value(problem["answer"], previous_answer):
		return false
	if not allow_duplicate_question and generated_question_texts.has(str(problem["text"])):
		return false
	return true


func _remember_generated_question(problem: Dictionary) -> void:
	generated_question_texts[str(problem["text"])] = true


func _can_repeat_question_for_current_series() -> bool:
	return generated_question_texts.size() >= _unique_question_count_for_current_series()


func _unique_question_count_for_current_series() -> int:
	var series: Dictionary = series_options[selected_series_index]
	var op := str(series["op"])
	if op == "make_five":
		return 4
	if op == "make_ten":
		return 9
	return 1000000


func _same_answer_value(left, right) -> bool:
	return abs(float(left) - float(right)) <= ANSWER_EPSILON


func _make_problem(a: int, b: int, symbol: String, answer, question_number: int) -> Dictionary:
	var series: Dictionary = series_options[selected_series_index]
	return {
		"text": "%d %s %d = ?" % [a, symbol, b],
		"answer": answer,
		"series": _series_display_name(series),
		"number": question_number
	}


func _make_group_problem(a: int, b: int, left: String, right: String, answer: int, question_number: int) -> Dictionary:
	var series: Dictionary = series_options[selected_series_index]
	return {
		"text": "%s%d, %d%s = ?" % [left, a, b, right],
		"answer": answer,
		"series": _series_display_name(series),
		"number": question_number
	}


func _make_remainder_problem(a: int, b: int, answer: int, question_number: int) -> Dictionary:
	var series: Dictionary = series_options[selected_series_index]
	return {
		"text": "%d %% %d = ?" % [a, b],
		"answer": answer,
		"series": _series_display_name(series),
		"number": question_number
	}


func _make_decimal_problem(a: float, b: float, symbol: String, answer: float, decimal_places: int, question_number: int) -> Dictionary:
	var series: Dictionary = series_options[selected_series_index]
	return {
		"text": "%s %s %s = ?" % [_format_decimal(a, decimal_places), symbol, _format_decimal(b, decimal_places)],
		"answer": answer,
		"series": _series_display_name(series),
		"number": question_number
	}


func _decimal_value(decimal_places: int) -> float:
	var scale := int(pow(10.0, decimal_places))
	return float(_decimal_units(decimal_places)) / float(scale)


func _decimal_sub_values(decimal_places: int) -> Array:
	var scale := int(pow(10.0, decimal_places))
	var a_units := _decimal_units(decimal_places)
	var b_units := _decimal_units(decimal_places)
	while b_units >= a_units:
		a_units = _decimal_units(decimal_places)
		b_units = _decimal_units(decimal_places)
	return [float(a_units) / float(scale), float(b_units) / float(scale)]


func _decimal_units(decimal_places: int) -> int:
	var scale := int(pow(10.0, decimal_places))
	var integer_part := rng.randi_range(0, 98)
	return integer_part * scale + _nonzero_fraction_units(decimal_places)


func _nonzero_fraction_units(decimal_places: int) -> int:
	if decimal_places == 1:
		return rng.randi_range(1, 9)
	var tens := rng.randi_range(0, 9)
	var ones := rng.randi_range(1, 9)
	return tens * 10 + ones


func _round_decimal(value: float, decimal_places: int) -> float:
	var scale := pow(10.0, decimal_places)
	return round(value * scale) / scale


func _format_decimal(value: float, decimal_places: int) -> String:
	if decimal_places == 1:
		return "%.1f" % value
	return "%.2f" % value


func _number_for_digits(digits: int) -> int:
	if digits == 1:
		return rng.randi_range(1, 9)
	return rng.randi_range(10, 99)


func _gcd(a: int, b: int) -> int:
	var x := int(abs(a))
	var y := int(abs(b))
	while y != 0:
		var temp: int = y
		y = x % y
		x = temp
	return x


func _lcm(a: int, b: int) -> int:
	return int(abs(a * b) / max(1, _gcd(a, b)))


func _on_keypad_pressed(value: String) -> void:
	if game_over or is_paused:
		return

	if value == "清空":
		answer_text = ""
		_update_answer_display()
	elif value == ".":
		if answer_text.find(".") == -1 and answer_text.length() < MAX_ANSWER_DIGITS:
			if answer_text == "":
				answer_text = "0"
			answer_text += "."
			_update_answer_display()
	elif answer_text.length() < MAX_ANSWER_DIGITS:
		answer_text += value
		_update_answer_display()


func _on_keypad_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_submit_answer()


func _update_answer_display() -> void:
	if answer_text == "":
		answer_display.text = ""
		if is_instance_valid(submit_hint_label):
			submit_hint_label.text = "提交答案"
		if is_instance_valid(submit_hint_sub_label):
			submit_hint_sub_label.text = "先点击数字键输入答案，然后点击此空白区域提交"
	else:
		answer_display.text = answer_text
		if is_instance_valid(submit_hint_label):
			submit_hint_label.text = "提交答案"
		if is_instance_valid(submit_hint_sub_label):
			submit_hint_sub_label.text = "点击此空白区域提交"
	answer_display.add_theme_color_override("font_color", COLOR_TEXT)


func _submit_answer() -> void:
	_release_keypad_focus()
	if game_over or is_paused:
		return

	var text := answer_text.strip_edges()
	if not text.is_valid_float() or text == ".":
		feedback_label.text = "请输入有效数字答案。"
		if is_instance_valid(submit_hint_label):
			submit_hint_label.text = "请先输入答案"
		if is_instance_valid(submit_hint_sub_label):
			submit_hint_sub_label.text = "点击数字键开始作答"
		return

	var answer := float(text)
	var elapsed := float(question_accumulated_msec + Time.get_ticks_msec() - question_started_msec) / 1000.0
	if min_duration == 0.0 or elapsed < min_duration:
		min_duration = elapsed
	if elapsed > max_duration:
		max_duration = elapsed
	if abs(answer - current_answer) <= ANSWER_EPSILON:
		current_count += 1
		max_streak_count = max(max_streak_count, current_count)
		correct_count += 1
		total_valid_duration += elapsed
		correct_records.append({
			"question": current_problem["text"],
			"duration": elapsed
		})
		answer_records.append({
			"question": current_problem["text"],
			"duration": elapsed,
			"correct": true
		})
		var damage := BASE_DAMAGE
		_deal_damage_to_boss(damage)
		feedback_label.text = "答对了！Boss 受到 %d 点伤害。" % damage
		_log("R%d 对，%.1fs，Boss -%d" % [round_index, elapsed, damage])
	else:
		current_count = 0
		wrong_count += 1
		answer_records.append({
			"question": current_problem["text"],
			"duration": -0.1,
			"actual_duration": elapsed,
			"correct": false
		})
		_take_boss_damage(1)
		feedback_label.text = "答错了，正确答案是 %s。玩家受到 1 点伤害。" % _format_answer(current_answer)
		_log("R%d 错，答案 %s，玩家 -1" % [round_index, _format_answer(current_answer)])

	_end_round_or_continue()


func _release_keypad_focus() -> void:
	_release_ui_focus()


func _release_ui_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()


func _format_answer(value: float) -> String:
	if abs(value - round(value)) <= ANSWER_EPSILON:
		return str(int(round(value)))
	var text := "%.3f" % value
	while text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return text


func _show_stats_screen() -> void:
	in_battle_screen = false
	_clear_screen()

	var retry_button := _make_header_icon_button(icon_retry, "再练一次")
	retry_button.pressed.connect(_request_start_new_game)

	var back_button := _make_header_icon_button(icon_home, "返回选择")
	back_button.pressed.connect(_request_show_start_screen)

	var root := _make_standard_screen_root("战斗统计", 32, [retry_button, back_button])

	var series: Dictionary = series_options[selected_series_index]
	var answer_count := correct_count + wrong_count
	var count_accuracy := _calculate_count_accuracy(correct_count, wrong_count)
	var duration := _calculate_duration()
	var average_duration := duration / float(answer_count) if answer_count > 0 else 0.0
	var current_record := _build_stats_record(series, count_accuracy, duration, average_duration)
	var score := int(current_record["score"])
	var accuracy_score := int(current_record["accuracy_score"])
	var duration_score := int(current_record["duration_score"])
	if not current_stats_saved:
		_save_stats_record(current_record)
		current_stats_saved = true

	var cards_row := HBoxContainer.new()
	cards_row.custom_minimum_size = Vector2(0, STATS_CARD_ROW_HEIGHT)
	cards_row.add_theme_constant_override("separation", 10)
	root.add_child(cards_row)

	cards_row.add_child(_make_stat_card("玩家信息", [
		_series_code(series),
		selected_user
	], COLOR_TEXT))
	cards_row.add_child(_make_stat_card("本局积分", [
		str(score),
		"%d + %d" % [accuracy_score, duration_score]
	], COLOR_SECONDARY))
	cards_row.add_child(_make_stat_card("正确率", [
		_format_percent(count_accuracy),
		"正确 %d / 错误 %d" % [correct_count, wrong_count],
		"连击 %d" % max_streak_count
	], COLOR_CORRECT))
	cards_row.add_child(_make_stat_card("时间", [
		"%.2fs" % duration,
		"最快 %.2fs / 最慢 %.2fs" % [min_duration, max_duration],
		"平均 %.2fs" % average_duration
	], COLOR_STATE))

	var narrow_layout := _is_portrait_layout()
	var charts = VBoxContainer.new() if narrow_layout else HBoxContainer.new()
	charts.custom_minimum_size = Vector2(0, STATS_CHART_HEIGHT)
	charts.add_theme_constant_override("separation", 12)
	root.add_child(charts)

	if not narrow_layout:
		charts.add_child(_make_accuracy_chart(correct_count, wrong_count))
	charts.add_child(_make_time_chart())

	root.add_child(_make_history_table(_load_stats_history()))


func _make_stat_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	_apply_font(label, font_size, "font")
	return label


func _make_stat_card(title_text: String, lines: Array, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, STATS_CARD_ROW_HEIGHT)
	panel.add_theme_stylebox_override("panel", _make_area_style(COLOR_PRIMARY, 0.62))

	var box := VBoxContainer.new()
	box.offset_left = 16
	box.offset_top = 10
	box.offset_right = -16
	box.offset_bottom = -10
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)

	var title := _make_card_header_label(title_text)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title)

	for i in range(lines.size()):
		var line := _make_stat_label(str(lines[i]), 20 if i == 0 else 13, accent if i == 0 else COLOR_TEXT)
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.clip_text = true
		box.add_child(line)
	return panel


func _make_accuracy_chart(valid_count: int, excluded_count: int) -> PanelContainer:
	var panel := _make_chart_container("正确率统计")
	var chart_box: VBoxContainer = panel.get_child(0)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	chart_box.add_child(body)

	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left_spacer)

	var pie := TextureRect.new()
	pie.texture = _make_accuracy_pie_texture(valid_count, excluded_count, 128)
	pie.custom_minimum_size = Vector2(128, 128)
	pie.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pie.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.add_child(pie)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right_spacer)
	return panel


func _make_time_chart() -> PanelContainer:
	var panel := _make_chart_container("时间统计")
	var chart_box: VBoxContainer = panel.get_child(0)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	chart_box.add_child(body)

	if answer_records.is_empty():
		body.add_child(_make_stat_label("暂无答题用时", 20, COLOR_MUTED_TEXT))
		return panel

	var max_duration_value := 0.1
	for record in answer_records:
		var item: Dictionary = record
		max_duration_value = max(max_duration_value, max(0.0, float(item["duration"])))

	var records_to_show: int = answer_records.size()
	for i in range(records_to_show):
		var record: Dictionary = answer_records[i]
		var is_correct := bool(record["correct"])
		body.add_child(_make_bar(str(i + 1), float(record["duration"]), max_duration_value, COLOR_CORRECT if is_correct else COLOR_WRONG))
	return panel


func _calculate_count_accuracy(correct: int, wrong: int) -> float:
	var total := correct + wrong
	if total == 0:
		return 0.0
	return float(correct) / float(total)


func _calculate_duration() -> float:
	var total := 0.0
	for record in answer_records:
		var item: Dictionary = record
		if bool(item["correct"]):
			total += float(item["duration"])
		else:
			total += float(item["actual_duration"])
	return total


func _format_percent(value: float) -> String:
	return "%.1f%%" % [value * 100.0]


func _calculate_score(count_accuracy: float, duration_value: float) -> int:
	return _calculate_accuracy_score(count_accuracy) + _calculate_duration_score(duration_value)


func _calculate_accuracy_score(count_accuracy: float) -> int:
	return int(floor(count_accuracy * 100.0))


func _calculate_duration_score(duration_value: float) -> int:
	return max(0, 60 - int(floor(duration_value)))


func _get_record_score(record: Dictionary) -> int:
	return _calculate_score(_record_count_accuracy(record), _record_duration(record))


func _get_record_accuracy_score(record: Dictionary) -> int:
	return _calculate_accuracy_score(_record_count_accuracy(record))


func _get_record_duration_score(record: Dictionary) -> int:
	return _calculate_duration_score(_record_duration(record))


func _difficulty_code(series_name: String) -> String:
	var parts := series_name.split(" ")
	return parts[0] if parts.size() > 0 else series_name


func _difficulty_title(series_name: String) -> String:
	var parts := series_name.split(" ", false, 1)
	return parts[1] if parts.size() > 1 else series_name


func _series_code(series: Dictionary) -> String:
	return str(series.get("key", _difficulty_code(str(series.get("name", "")))))


func _series_title(series: Dictionary) -> String:
	return str(series.get("name", ""))


func _series_display_name(series: Dictionary) -> String:
	return "%s %s" % [_series_code(series), _series_title(series)]


func _record_player(record: Dictionary) -> String:
	return str(record.get("player", ""))


func _record_level(record: Dictionary) -> String:
	return str(record.get("level", ""))


func _record_series_name(record: Dictionary) -> String:
	var level := _record_level(record)
	for series in series_options:
		var item: Dictionary = series
		if _series_code(item) == level:
			return _series_display_name(item)
	return level


func _record_count_accuracy(record: Dictionary) -> float:
	return float(record.get("count_accuracy", 0.0))


func _record_max_streak_count(record: Dictionary) -> int:
	return int(record.get("max_streak_count", 0))


func _record_correct_count(record: Dictionary) -> int:
	return int(record.get("correct_count", 0))


func _record_wrong_count(record: Dictionary) -> int:
	return int(record.get("wrong_count", 0))


func _record_duration(record: Dictionary) -> float:
	return float(record.get("duration", 0.0))


func _record_average_duration(record: Dictionary) -> float:
	return float(record.get("average_duration", 0.0))


func _record_min_duration(record: Dictionary) -> float:
	return float(record.get("min_duration", 0.0))


func _record_max_duration(record: Dictionary) -> float:
	return float(record.get("max_duration", 0.0))


func _build_stats_record(series: Dictionary, count_accuracy: float, duration_value: float, average_duration: float) -> Dictionary:
	var accuracy_score := _calculate_accuracy_score(count_accuracy)
	var duration_score := _calculate_duration_score(duration_value)
	var score := _calculate_score(count_accuracy, duration_value)
	return {
		"id": "%d-%d" % [Time.get_unix_time_from_system(), randi()],
		"date": Time.get_datetime_string_from_system(false, true),
		"player": selected_user,
		"level": _series_code(series),
		"score": score,
		"accuracy_score": accuracy_score,
		"duration_score": duration_score,
		"correct_count": correct_count,
		"wrong_count": wrong_count,
		"count_accuracy": count_accuracy,
		"max_streak_count": max_streak_count,
		"duration": duration_value,
		"average_duration": average_duration,
		"min_duration": min_duration,
		"max_duration": max_duration
	}


func _load_stats_history() -> Array:
	if not FileAccess.file_exists(STATS_FILE_PATH):
		return []
	var file := FileAccess.open(STATS_FILE_PATH, FileAccess.READ)
	if file == null:
		push_warning("无法读取统计历史：%s" % STATS_FILE_PATH)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		return parsed
	push_warning("统计历史格式无效：%s" % STATS_FILE_PATH)
	return []


func _save_stats_record(record: Dictionary) -> void:
	var history := _load_stats_history()
	history.append(record)
	if history.size() > 200:
		history = history.slice(history.size() - 200)
	var file := FileAccess.open(STATS_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("无法保存统计历史：%s" % STATS_FILE_PATH)
		return
	file.store_string(JSON.stringify(history, "\t"))


func _export_current_stats_csv(history: Array) -> void:
	var rows: Array = []
	for record in history:
		if record is Dictionary and _is_current_player_series_record(record):
			rows.append(record)
	var series: Dictionary = series_options[selected_series_index]
	var filename := "%s%s.csv" % [_sanitize_filename(selected_user), _series_code(series)]
	var csv := _build_stats_csv(rows)
	if OS.has_feature("web"):
		var script := "const data = new Blob([%s], {type: 'text/csv;charset=utf-8'}); const url = URL.createObjectURL(data); const a = document.createElement('a'); a.href = url; a.download = %s; document.body.appendChild(a); a.click(); a.remove(); URL.revokeObjectURL(url);" % [JSON.stringify(csv), JSON.stringify(filename)]
		JavaScriptBridge.eval(script, true)
		return
	var file := FileAccess.open("user://%s" % filename, FileAccess.WRITE)
	if file == null:
		push_warning("无法导出战斗记录：%s" % filename)
		return
	file.store_string(csv)
	file.close()
	OS.shell_open(ProjectSettings.globalize_path("user://"))


func _build_stats_csv(rows: Array) -> String:
	var lines := []
	lines.append(_csv_row(["date", "player", "level", "score", "accuracy_score", "duration_score", "correct_count", "wrong_count", "count_accuracy", "max_streak_count", "duration", "average_duration", "min_duration", "max_duration"]))
	for row in rows:
		var item: Dictionary = row
		lines.append(_csv_row([
			_format_csv_datetime(str(item.get("date", ""))),
			_record_player(item),
			_record_level(item),
			str(_get_record_score(item)),
			str(_get_record_accuracy_score(item)),
			str(_get_record_duration_score(item)),
			str(_record_correct_count(item)),
			str(_record_wrong_count(item)),
			_format_percent(_record_count_accuracy(item)),
			str(_record_max_streak_count(item)),
			"%.2f" % [_record_duration(item)],
			"%.2f" % [_record_average_duration(item)],
			"%.2f" % [_record_min_duration(item)],
			"%.2f" % [_record_max_duration(item)]
		]))
	return "\n".join(lines)


func _csv_row(values: Array) -> String:
	var escaped := []
	for value in values:
		escaped.append(_csv_escape(str(value)))
	return ",".join(escaped)


func _csv_escape(value: String) -> String:
	var escaped := value.replace("\"", "\"\"")
	return "\"%s\"" % escaped


func _sanitize_filename(value: String) -> String:
	var result := value
	for token in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|", " "]:
		result = result.replace(token, "")
	return result if not result.is_empty() else "player"


func _make_accuracy_pie_texture(valid_count: int, excluded_count: int, size: int) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var total := valid_count + excluded_count
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := float(size) * 0.46
	if total == 0:
		total = 1
	var correct_angle := TAU * float(valid_count) / float(total)
	for y in range(size):
		for x in range(size):
			var point := Vector2(x + 0.5, y + 0.5)
			var offset := point - center
			if offset.length() <= radius:
				var angle := atan2(offset.y, offset.x)
				if angle < 0.0:
					angle += TAU
				image.set_pixel(x, y, COLOR_CORRECT if angle <= correct_angle else COLOR_WRONG)
	return ImageTexture.create_from_image(image)


func _make_legend_label(text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(18, 18)
	row.add_child(swatch)
	var label := _make_stat_label(text, 18, COLOR_TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _make_history_table(history: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, STATS_HISTORY_HEIGHT)
	panel.add_theme_stylebox_override("panel", _make_area_style(COLOR_PRIMARY, 0.48))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	box.add_child(title_row)
	var title := _make_card_header_label("战斗记录")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var export_button := Button.new()
	export_button.text = "导出历史记录"
	export_button.custom_minimum_size = Vector2(148, 30)
	_apply_font(export_button, 14, "font")
	_apply_button_style(export_button)
	export_button.pressed.connect(_export_current_stats_csv.bind(history))
	title_row.add_child(export_button)

	var rows := _select_history_rows(history)
	if rows.is_empty():
		box.add_child(_make_stat_label("暂无历史记录", 18, COLOR_MUTED_TEXT))
		return panel

	var table := VBoxContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("separation", 2)
	box.add_child(table)

	_add_history_row(table, ["日期", "积分", "正确率", "连击", "总时间", "平均"], COLOR_BUTTON_ACTIVE, true)

	var best_record := _find_best_score_record(history)
	for row in rows:
		var item: Dictionary = row
		var highlighted := _same_stats_record(item, best_record)
		var background := COLOR_BUTTON_ACTIVE if highlighted else COLOR_PRIMARY
		background.a = 0.78 if highlighted else 0.42
		var values := [
			_format_history_datetime(str(item.get("date", ""))),
			str(_get_record_score(item)),
			_format_percent(_record_count_accuracy(item)),
			str(_record_max_streak_count(item)),
			"%.2fs" % [_record_duration(item)],
			"%.2fs" % [_record_average_duration(item)]
		]
		_add_history_row(table, values, background, false)
	return panel


func _select_history_rows(history: Array) -> Array:
	var matching_rows: Array = []
	var index := history.size() - 1
	var skipped_current_record := not current_stats_saved
	while index >= 0:
		var record: Variant = history[index]
		if record is Dictionary and _is_current_player_series_record(record):
			if not skipped_current_record:
				skipped_current_record = true
				index -= 1
				continue
			matching_rows.append(record)
		index -= 1

	var best_record: Dictionary = {}
	for row in matching_rows:
		var item: Dictionary = row
		if best_record.is_empty() or _get_record_score(item) > _get_record_score(best_record):
			best_record = item
		elif _get_record_score(item) == _get_record_score(best_record) and _record_average_duration(item) < _record_average_duration(best_record):
			best_record = item

	var rows_to_show: Array = []
	for row in matching_rows:
		var item: Dictionary = row
		if not best_record.is_empty() and _same_stats_record(item, best_record):
			continue
		rows_to_show.append(item)
		if rows_to_show.size() == 2:
			break
	if not best_record.is_empty():
		rows_to_show.append(best_record)
	elif matching_rows.size() > 0:
		while rows_to_show.size() < 3 and rows_to_show.size() < matching_rows.size():
			rows_to_show.append(matching_rows[rows_to_show.size()])
	return rows_to_show


func _find_best_score_record(history: Array) -> Dictionary:
	var best: Dictionary = {}
	for record in history:
		if not (record is Dictionary):
			continue
		var item: Dictionary = record
		if not _is_current_player_series_record(item):
			continue
		if best.is_empty() or _get_record_score(item) > _get_record_score(best):
			best = item
		elif not best.is_empty() and _get_record_score(item) == _get_record_score(best) and _record_average_duration(item) < _record_average_duration(best):
			best = item
	return best


func _get_best_score_for_series(history: Array, series_name: String) -> int:
	var best_score := -100000
	var series_code := _difficulty_code(series_name)
	for record in history:
		if not (record is Dictionary):
			continue
		var item: Dictionary = record
		if _record_player(item) != selected_user or _difficulty_code(_record_series_name(item)) != series_code:
			continue
		best_score = max(best_score, _get_record_score(item))
	return best_score


func _is_current_player_series_record(record: Dictionary) -> bool:
	var series: Dictionary = series_options[selected_series_index]
	return _record_player(record) == selected_user and _difficulty_code(_record_series_name(record)) == _series_code(series)


func _same_stats_record(left: Dictionary, right: Dictionary) -> bool:
	if left.is_empty() or right.is_empty():
		return false
	return str(left.get("id", "")) == str(right.get("id", ""))


func _format_history_datetime(value: String) -> String:
	value = value.replace("T", " ")
	if value.length() >= 16:
		return value.substr(0, 16)
	return value


func _format_csv_datetime(value: String) -> String:
	value = value.replace("T", " ")
	if value.length() >= 19:
		return value.substr(0, 19)
	if value.length() == 16:
		return "%s:00" % value
	return value


func _add_history_row(table: VBoxContainer, values: Array, background: Color, is_header: bool) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 2)
	table.add_child(row)
	for i in range(values.size()):
		var ratio := 1.0
		if i == 0:
			ratio = 1.5
		elif i == 2:
			ratio = 1.1
		var color := COLOR_TEXT
		row.add_child(_make_table_cell(str(values[i]), color, background, ratio))


func _make_table_cell(text: String, color: Color, background: Color, ratio: float) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_stretch_ratio = ratio
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	cell.add_theme_stylebox_override("panel", style)
	var label := _make_stat_label(text, 14, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(label)
	return cell


func _make_chart_container(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, STATS_CHART_HEIGHT)
	panel.add_theme_stylebox_override("panel", _make_area_style(COLOR_PRIMARY_LIGHT, 0.48))

	var box := VBoxContainer.new()
	box.offset_left = 16
	box.offset_top = 14
	box.offset_right = -16
	box.offset_bottom = -14
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := _make_centered_card_header_label(title_text)
	box.add_child(title)
	return panel


func _make_bar(label_text: String, value, max_value, color: Color) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(24, 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var bar := ColorRect.new()
	var ratio: float = max(0.0, float(value)) / max(0.001, float(max_value))
	var bar_height := 8.0 if float(value) < 0.0 else 14.0 + 76.0 * ratio
	bar.custom_minimum_size = Vector2(16, bar_height)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.color = color
	bar.color.a = 0.75
	column.add_child(bar)

	var value_label := Label.new()
	value_label.text = "" if float(value) < 0.0 else ("%.1f" % float(value) if typeof(value) == TYPE_FLOAT else str(value))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", COLOR_TEXT)
	_apply_font(value_label, 13, "font")
	column.add_child(value_label)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", COLOR_MUTED_TEXT)
	_apply_font(name_label, 13, "font")
	column.add_child(name_label)
	return column


func _deal_damage_to_boss(amount: int) -> void:
	boss_hp = max(0, boss_hp - amount)


func _take_boss_damage(amount: int) -> void:
	player_hp = max(0, player_hp - amount)


func _end_round_or_continue() -> void:
	if _check_game_over():
		_update_ui()
		return
	_next_question()


func _check_game_over() -> bool:
	if boss_hp <= 0:
		game_over = true
		feedback_label.text = "胜利！Boss 被击败。"
		_log("胜利")
	elif player_hp <= 0:
		game_over = true
		feedback_label.text = "失败！玩家生命归零。"
		_log("失败")
	elif round_index >= MAX_ROUNDS:
		game_over = true
		feedback_label.text = "练习完成！已完成本轮题目。"
		_log("完成")

	if game_over:
		for button in keypad_buttons:
			button.disabled = true
		call_deferred("_show_stats_screen")
	return game_over


func _update_ui() -> void:
	player_hp_label.text = "%d/%d" % [player_hp, PLAYER_MAX_HP]
	boss_hp_label.text = "%d/%d" % [boss_hp, boss_max_hp]
	player_hp_bar.max_value = PLAYER_MAX_HP
	player_hp_bar.value = player_hp
	boss_hp_bar.max_value = boss_max_hp
	boss_hp_bar.value = boss_hp

	for button in keypad_buttons:
		button.disabled = game_over or is_paused


func _log(message: String) -> void:
	var lines: Array = Array(log_label.text.split("\n", false))
	lines.push_front(message)
	while lines.size() > 4:
		lines.remove_at(lines.size() - 1)
	log_label.text = "\n".join(lines)
