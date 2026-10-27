class_name PokemonData
extends RefCounted

## 宝可梦静态数据库。种族值是唯一的等级成长源，不再使用原英雄的星级成长表。

const TABLE_PATH: String = "res://resources/data/Pokemon.json"
const DEFAULT_LEVEL: int = 30
const MIN_LEVEL: int = 1
const MAX_LEVEL: int = 100
const FIXED_IV: int = 20
const HP_BONUS: int = 10
const OTHER_BONUS: int = 5
const PERCENT_DENOMINATOR: int = 100
const TEAM_SIZE: int = 3
const BASE_STAT_MULTIPLIER: int = 2
const OFFENSE_POWER_WEIGHT: int = 2

const TYPE_CHART: Dictionary = {
	"normal": {"rock": 0.5, "ghost": 0.0, "steel": 0.5},
	"fire":
	{
		"fire": 0.5,
		"water": 0.5,
		"grass": 2.0,
		"ice": 2.0,
		"bug": 2.0,
		"rock": 0.5,
		"dragon": 0.5,
		"steel": 2.0
	},
	"water": {"fire": 2.0, "water": 0.5, "grass": 0.5, "ground": 2.0, "rock": 2.0, "dragon": 0.5},
	"electric":
	{"water": 2.0, "electric": 0.5, "grass": 0.5, "ground": 0.0, "flying": 2.0, "dragon": 0.5},
	"grass":
	{
		"fire": 0.5,
		"water": 2.0,
		"grass": 0.5,
		"poison": 0.5,
		"ground": 2.0,
		"flying": 0.5,
		"bug": 0.5,
		"rock": 2.0,
		"dragon": 0.5,
		"steel": 0.5,
	},
	"ice":
	{
		"fire": 0.5,
		"water": 0.5,
		"grass": 2.0,
		"ice": 0.5,
		"ground": 2.0,
		"flying": 2.0,
		"dragon": 2.0,
		"steel": 0.5,
	},
	"fighting":
	{
		"normal": 2.0,
		"ice": 2.0,
		"poison": 0.5,
		"flying": 0.5,
		"psychic": 0.5,
		"bug": 0.5,
		"rock": 2.0,
		"ghost": 0.0,
		"dark": 2.0,
		"steel": 2.0,
		"fairy": 0.5,
	},
	"poison":
	{
		"grass": 2.0,
		"poison": 0.5,
		"ground": 0.5,
		"rock": 0.5,
		"ghost": 0.5,
		"steel": 0.0,
		"fairy": 2.0
	},
	"ground":
	{
		"fire": 2.0,
		"electric": 2.0,
		"grass": 0.5,
		"poison": 2.0,
		"flying": 0.0,
		"bug": 0.5,
		"rock": 2.0,
		"steel": 2.0,
	},
	"flying":
	{"electric": 0.5, "grass": 2.0, "fighting": 2.0, "bug": 2.0, "rock": 0.5, "steel": 0.5},
	"psychic": {"fighting": 2.0, "poison": 2.0, "psychic": 0.5, "dark": 0.0, "steel": 0.5},
	"bug":
	{
		"fire": 0.5,
		"grass": 2.0,
		"fighting": 0.5,
		"poison": 0.5,
		"flying": 0.5,
		"psychic": 2.0,
		"ghost": 0.5,
		"dark": 2.0,
		"steel": 0.5,
		"fairy": 0.5,
	},
	"rock":
	{
		"fire": 2.0,
		"ice": 2.0,
		"fighting": 0.5,
		"ground": 0.5,
		"flying": 2.0,
		"bug": 2.0,
		"steel": 0.5
	},
	"ghost": {"normal": 0.0, "psychic": 2.0, "ghost": 2.0, "dark": 0.5},
	"dragon": {"dragon": 2.0, "steel": 0.5, "fairy": 0.0},
	"dark": {"fighting": 0.5, "psychic": 2.0, "ghost": 2.0, "dark": 0.5, "fairy": 0.5},
	"steel":
	{
		"fire": 0.5,
		"water": 0.5,
		"electric": 0.5,
		"ice": 2.0,
		"rock": 2.0,
		"steel": 0.5,
		"fairy": 2.0
	},
	"fairy":
	{"fire": 0.5, "fighting": 2.0, "poison": 0.5, "dragon": 2.0, "dark": 2.0, "steel": 0.5},
}

var _entries: Dictionary = {}


func load_catalog() -> bool:
	var file := FileAccess.open(TABLE_PATH, FileAccess.READ)
	if file == null:
		push_error("无法读取宝可梦数据表: " + TABLE_PATH)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("宝可梦数据表格式错误")
		return false
	_entries = parsed
	return not _entries.is_empty()


func count() -> int:
	return _entries.size()


func get_entry(pokemon_id: int) -> Dictionary:
	return _entries.get(str(pokemon_id), {})


func all_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in _entries:
		result.append(_entries[key])
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"])
	)
	return result


func search(query: String, type_filter: String = "", generation: int = 0) -> Array[Dictionary]:
	var normalized := query.strip_edges().to_lower()
	var result: Array[Dictionary] = []
	for entry in all_entries():
		if generation > 0 and int(entry["generation"]) != generation:
			continue
		if type_filter != "" and type_filter not in entry["types"]:
			continue
		var haystack := (
			(str(entry["name"]) + " " + str(entry["en"]) + " " + str(entry["dex_no"])).to_lower()
		)
		if normalized != "" and not normalized in haystack:
			continue
		result.append(entry)
	return result


func stats_at_level(pokemon_id: int, level: int) -> Dictionary:
	var entry := get_entry(pokemon_id)
	if entry.is_empty():
		return {}
	var base: Dictionary = entry["base_stats"]
	var safe_level := clampi(level, MIN_LEVEL, MAX_LEVEL)
	var result := {"hp": _hp_stat(int(base["hp"]), safe_level)}
	for field in ["attack", "defense", "sp_atk", "sp_def", "speed"]:
		result[field] = _other_stat(int(base[field]), safe_level)
	return result


func combat_power(pokemon_id: int, level: int = DEFAULT_LEVEL) -> int:
	var stats := stats_at_level(pokemon_id, level)
	if stats.is_empty():
		return 0
	return (
		int(stats["hp"])
		+ int(stats["attack"]) * OFFENSE_POWER_WEIGHT
		+ int(stats["defense"])
		+ int(stats["sp_atk"]) * OFFENSE_POWER_WEIGHT
		+ int(stats["sp_def"])
		+ int(stats["speed"])
	)


func type_multiplier(attack_type: String, defender_types: Array) -> float:
	var multiplier := 1.0
	var row: Dictionary = TYPE_CHART.get(attack_type, {})
	for defender_type in defender_types:
		multiplier *= float(row.get(str(defender_type), 1.0))
	return multiplier


func _hp_stat(base: int, level: int) -> int:
	return (
		int(((BASE_STAT_MULTIPLIER * base + FIXED_IV) * level) / PERCENT_DENOMINATOR)
		+ level
		+ HP_BONUS
	)


func _other_stat(base: int, level: int) -> int:
	return (
		int(((BASE_STAT_MULTIPLIER * base + FIXED_IV) * level) / PERCENT_DENOMINATOR) + OTHER_BONUS
	)
