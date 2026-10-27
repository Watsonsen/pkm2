class_name PokemonBattleSimulator
extends RefCounted

## 宝可梦三人小队的轻量模拟器（Logic 层，无 UI 依赖）。

const TEAM_SIZE: int = 3
const DEFAULT_LEVEL: int = 30
const ROLL_MIN: float = 0.92
const ROLL_MAX: float = 1.08

var _catalog: Variant
var _rng: RandomNumberGenerator


func _init(catalog: Variant, seed: int = 0) -> void:
	_catalog = catalog
	_rng = RandomNumberGenerator.new()
	if seed == 0:
		_rng.randomize()
	else:
		_rng.seed = seed


func simulate(team_ids: Array, level: int = DEFAULT_LEVEL) -> Dictionary:
	if team_ids.size() != TEAM_SIZE:
		return {"won": false, "error": "请先组建 3 只宝可梦的队伍", "rounds": []}
	var enemies := _random_enemy_team()
	var rounds: Array[Dictionary] = []
	var player_score := 0.0
	var enemy_score := 0.0
	for index in range(TEAM_SIZE):
		var ally_id := int(team_ids[index])
		var ally: Dictionary = _catalog.get_entry(ally_id)
		var enemy: Dictionary = _catalog.get_entry(enemies[index])
		var ally_type := str(ally["types"][0])
		var enemy_type := str(enemy["types"][0])
		var ally_multiplier: float = _catalog.type_multiplier(ally_type, enemy["types"])
		var enemy_multiplier: float = _catalog.type_multiplier(enemy_type, ally["types"])
		var ally_roll := _rng.randf_range(ROLL_MIN, ROLL_MAX)
		var enemy_roll := _rng.randf_range(ROLL_MIN, ROLL_MAX)
		var ally_round_score: float = (
			float(_catalog.combat_power(ally_id, level)) * ally_multiplier * ally_roll
		)
		var enemy_round_score: float = (
			float(_catalog.combat_power(enemies[index], level)) * enemy_multiplier * enemy_roll
		)
		player_score += ally_round_score
		enemy_score += enemy_round_score
		(
			rounds
			. append(
				{
					"ally": ally["name"],
					"enemy": enemy["name"],
					"ally_multiplier": ally_multiplier,
					"enemy_multiplier": enemy_multiplier,
					"won": ally_round_score >= enemy_round_score,
				}
			)
		)
	return {
		"won": player_score >= enemy_score,
		"player_score": roundi(player_score),
		"enemy_score": roundi(enemy_score),
		"enemy_ids": enemies,
		"rounds": rounds,
	}


func _random_enemy_team() -> Array[int]:
	var result: Array[int] = []
	while result.size() < TEAM_SIZE:
		var candidate := _rng.randi_range(1, _catalog.count())
		if candidate not in result:
			result.append(candidate)
	return result
