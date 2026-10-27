extends Control

## 宝可梦远征主界面（View 层）：图鉴筛选、种族值详情、技能与三人编队。

const PokemonDataScript = preload("res://scripts/data/pokemon_data.gd")
const BattleSimulatorScript = preload("res://scripts/systems/pokemon_battle_simulator.gd")
const StageSelectPanel = preload("res://scripts/ui/stage_select_panel.gd")
const PAGE_SIZE: int = 24
const CARD_COLUMNS: int = 4
const ART_SIZE: float = 176.0
const STAT_MAX: int = 255

const TYPE_OPTIONS: Array[Array] = [
	["全部属性", ""],
	["一般", "normal"],
	["火", "fire"],
	["水", "water"],
	["电", "electric"],
	["草", "grass"],
	["冰", "ice"],
	["格斗", "fighting"],
	["毒", "poison"],
	["地面", "ground"],
	["飞行", "flying"],
	["超能力", "psychic"],
	["虫", "bug"],
	["岩石", "rock"],
	["幽灵", "ghost"],
	["龙", "dragon"],
	["恶", "dark"],
	["钢", "steel"],
	["妖精", "fairy"],
]
const STAT_LABELS: Dictionary = {
	"hp": "HP",
	"attack": "攻击",
	"defense": "防御",
	"sp_atk": "特攻",
	"sp_def": "特防",
	"speed": "速度",
}
const TYPE_COLORS: Dictionary = {
	"normal": Color("#a8a77a"),
	"fire": Color("#ee8130"),
	"water": Color("#6390f0"),
	"electric": Color("#f7d02c"),
	"grass": Color("#7ac74c"),
	"ice": Color("#96d9d6"),
	"fighting": Color("#c22e28"),
	"poison": Color("#a33ea1"),
	"ground": Color("#e2bf65"),
	"flying": Color("#a98ff3"),
	"psychic": Color("#f95587"),
	"bug": Color("#a6b91a"),
	"rock": Color("#b6a136"),
	"ghost": Color("#735797"),
	"dragon": Color("#6f35fc"),
	"dark": Color("#705746"),
	"steel": Color("#b7b7ce"),
	"fairy": Color("#d685ad"),
}

var _catalog := PokemonDataScript.new()
var _simulator: RefCounted
var _results: Array[Dictionary] = []
var _team: Array[int] = []
var _page: int = 0
var _selected_id: int = 1
var _level: int = PokemonDataScript.DEFAULT_LEVEL

var _search: LineEdit
var _type_filter: OptionButton
var _generation_filter: OptionButton
var _grid: GridContainer
var _page_label: Label
var _artwork: TextureRect
var _name_label: Label
var _meta_label: Label
var _level_label: Label
var _flavor_label: Label
var _stats_box: VBoxContainer
var _skills_box: VBoxContainer
var _team_box: HBoxContainer
var _battle_log: RichTextLabel


func _ready() -> void:
	if not _catalog.load_catalog():
		_show_fatal("宝可梦数据加载失败")
		return
	_simulator = BattleSimulatorScript.new(_catalog)
	_build_interface()
	_refresh_results()
	_select_pokemon(_selected_id)


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#08111f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(_build_header())
	root.add_child(_build_main_content())
	root.add_child(_build_team_bar())


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "◆ 宝可梦远征"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("#f8d648"))
	row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索名称 / 英文 / #编号"
	_search.custom_minimum_size.x = 210
	_search.text_changed.connect(_on_filter_changed.unbind(1))
	row.add_child(_search)
	_type_filter = OptionButton.new()
	for option in TYPE_OPTIONS:
		_type_filter.add_item(str(option[0]))
		_type_filter.set_item_metadata(_type_filter.item_count - 1, option[1])
	_type_filter.item_selected.connect(_on_filter_changed.unbind(1))
	row.add_child(_type_filter)
	_generation_filter = OptionButton.new()
	_generation_filter.add_item("全部世代")
	for generation in range(1, 10):
		_generation_filter.add_item("第 %d 世代" % generation)
	_generation_filter.item_selected.connect(_on_filter_changed.unbind(1))
	row.add_child(_generation_filter)
	return row


func _build_main_content() -> Control:
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 465
	var browser := VBoxContainer.new()
	browser.custom_minimum_size.x = 440
	browser.add_theme_constant_override("separation", 8)
	split.add_child(browser)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	browser.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = CARD_COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 7)
	_grid.add_theme_constant_override("v_separation", 7)
	scroll.add_child(_grid)
	browser.add_child(_build_pager())
	split.add_child(_build_detail_panel())
	return split


func _build_pager() -> Control:
	var row := HBoxContainer.new()
	var previous := Button.new()
	previous.text = "← 上一页"
	previous.pressed.connect(_change_page.bind(-1))
	row.add_child(previous)
	_page_label = Label.new()
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_page_label)
	var next := Button.new()
	next.text = "下一页 →"
	next.pressed.connect(_change_page.bind(1))
	row.add_child(next)
	return row


func _build_detail_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 300
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111f35")
	style.border_color = Color("#29456d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	_artwork = TextureRect.new()
	_artwork.custom_minimum_size = Vector2(ART_SIZE, ART_SIZE)
	_artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(_artwork)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 23)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name_label)
	_meta_label = Label.new()
	_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_meta_label)
	box.add_child(_build_level_control())
	_flavor_label = Label.new()
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor_label.add_theme_color_override("font_color", Color("#b8c7df"))
	box.add_child(_flavor_label)
	_stats_box = VBoxContainer.new()
	box.add_child(_stats_box)
	_skills_box = VBoxContainer.new()
	box.add_child(_skills_box)
	var add_button := Button.new()
	add_button.text = "＋ 加入远征队"
	add_button.pressed.connect(_add_selected_to_team)
	box.add_child(add_button)
	return panel


func _build_level_control() -> Control:
	var row := HBoxContainer.new()
	_level_label = Label.new()
	_level_label.custom_minimum_size.x = 58
	row.add_child(_level_label)
	var slider := HSlider.new()
	slider.min_value = PokemonDataScript.MIN_LEVEL
	slider.max_value = PokemonDataScript.MAX_LEVEL
	slider.step = 1
	slider.value = PokemonDataScript.DEFAULT_LEVEL
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_level_changed)
	row.add_child(slider)
	return row


func _build_team_bar() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 66
	var label := Label.new()
	label.text = "远征队  "
	label.add_theme_font_size_override("font_size", 17)
	row.add_child(label)
	_team_box = HBoxContainer.new()
	_team_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_team_box)
	_battle_log = RichTextLabel.new()
	_battle_log.bbcode_enabled = true
	_battle_log.custom_minimum_size = Vector2(220, 58)
	row.add_child(_battle_log)
	var battle := Button.new()
	battle.text = "▶ 模拟对战"
	battle.pressed.connect(_run_battle)
	row.add_child(battle)
	_refresh_team()
	return row


func _on_filter_changed() -> void:
	_page = 0
	_refresh_results()


func _refresh_results() -> void:
	var type_key := str(_type_filter.get_selected_metadata())
	_results = _catalog.search(_search.text, type_key, _generation_filter.selected)
	var page_count := maxi(1, ceili(float(_results.size()) / float(PAGE_SIZE)))
	_page = clampi(_page, 0, page_count - 1)
	_page_label.text = "%d / %d  ·  %d 只" % [_page + 1, page_count, _results.size()]
	_clear(_grid)
	var start := _page * PAGE_SIZE
	var finish := mini(start + PAGE_SIZE, _results.size())
	for index in range(start, finish):
		_grid.add_child(_make_card(_results[index]))


func _make_card(entry: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(103, 72)
	card.text = "%s\n%s" % [entry["dex_no"], entry["name"]]
	card.tooltip_text = "%s  ·  %s" % [_join_strings(entry["types_cn"], "/"), entry["role"]]
	card.icon = load(str(entry["artwork"])) as Texture2D
	card.add_theme_constant_override("icon_max_width", 48)
	card.expand_icon = true
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.pressed.connect(_select_pokemon.bind(int(entry["id"])))
	var primary_type := str(entry["types"][0])
	card.add_theme_color_override("font_hover_color", TYPE_COLORS.get(primary_type, Color.WHITE))
	return card


func _change_page(delta: int) -> void:
	_page += delta
	_refresh_results()


func _on_level_changed(value: float) -> void:
	_level = int(value)
	_select_pokemon(_selected_id)


func _select_pokemon(pokemon_id: int) -> void:
	_selected_id = pokemon_id
	var entry := _catalog.get_entry(pokemon_id)
	if entry.is_empty():
		return
	_artwork.texture = load(str(entry["artwork"])) as Texture2D
	_name_label.text = "%s  %s" % [entry["dex_no"], entry["name"]]
	_meta_label.text = (
		"%s  ·  %s  ·  种族值 %d  ·  战力 %d"
		% [
			_join_strings(entry["types_cn"], " / "),
			entry["role"],
			entry["base_stat_total"],
			_catalog.combat_power(pokemon_id, _level),
		]
	)
	_level_label.text = "Lv.%d" % _level
	_flavor_label.text = str(entry["flavor"])
	_fill_stats(entry["base_stats"], _catalog.stats_at_level(pokemon_id, _level))
	_fill_skills(entry["skills"])


func _fill_stats(base_stats: Dictionary, level_stats: Dictionary) -> void:
	_clear(_stats_box)
	for field in STAT_LABELS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = str(STAT_LABELS[field])
		label.custom_minimum_size.x = 44
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.max_value = STAT_MAX
		bar.value = int(base_stats[field])
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)
		var value := Label.new()
		value.text = "%s → %s" % [base_stats[field], level_stats[field]]
		value.custom_minimum_size.x = 72
		row.add_child(value)
		_stats_box.add_child(row)


func _fill_skills(skills: Array) -> void:
	_clear(_skills_box)
	for skill in skills:
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.text = (
			"[b]%s[/b]  [color=#8fb7ff]%s[/color]\n%s"
			% [skill["name"], skill["kind"], skill["description"]]
		)
		_skills_box.add_child(text)


func _add_selected_to_team() -> void:
	if _selected_id in _team:
		_battle_log.text = "[color=#ffd75e]该宝可梦已在队伍中[/color]"
		return
	if _team.size() >= PokemonDataScript.TEAM_SIZE:
		_team.pop_front()
	_team.append(_selected_id)
	_refresh_team()


func _refresh_team() -> void:
	_clear(_team_box)
	for slot in range(PokemonDataScript.TEAM_SIZE):
		var button := Button.new()
		button.custom_minimum_size = Vector2(88, 48)
		if slot < _team.size():
			var entry := _catalog.get_entry(_team[slot])
			button.text = "%d. %s" % [slot + 1, entry["name"]]
			button.icon = load(str(entry["artwork"])) as Texture2D
			button.add_theme_constant_override("icon_max_width", 36)
			button.pressed.connect(_remove_team_slot.bind(slot))
		else:
			button.text = "%d. 待选择" % [slot + 1]
			button.disabled = true
		_team_box.add_child(button)


func _remove_team_slot(slot: int) -> void:
	_team.remove_at(slot)
	_refresh_team()


func _run_battle() -> void:
	var result: Dictionary = _simulator.simulate(_team, _level)
	if result.has("error"):
		_battle_log.text = "[color=#ff8585]%s[/color]" % result["error"]
		return
	var lines: Array[String] = []
	for round_data in result["rounds"]:
		var marker := "●" if round_data["won"] else "○"
		lines.append(
			(
				"%s %s vs %s  ×%.1f"
				% [marker, round_data["ally"], round_data["enemy"], round_data["ally_multiplier"]]
			)
		)
	var color := "#79e6a5" if result["won"] else "#ff8585"
	_battle_log.text = (
		"[color=%s][b]%s[/b][/color]  %d : %d\n%s"
		% [
			color,
			"远征胜利" if result["won"] else "远征失败",
			result["player_score"],
			result["enemy_score"],
			_join_strings(lines, "  "),
		]
	)


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		child.free()


func _join_strings(values: Array, separator: String) -> String:
	var parts: PackedStringArray = []
	for value in values:
		parts.append(str(value))
	return separator.join(parts)


func _show_fatal(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(label)


## 保留脚手架的装备获取途径反射入口，避免旧面板跳转断链。
func open_stage_select_by_stage(stage_id: int) -> void:
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_by_stage(
		GameData.player.stage_manager, GameData.player, BattleRng.new(randi()), stage_id
	)
	panel.show_window(self)
