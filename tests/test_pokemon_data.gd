extends GutTest

const PokemonDataScript = preload("res://scripts/data/pokemon_data.gd")
const BattleSimulatorScript = preload("res://scripts/systems/pokemon_battle_simulator.gd")

var catalog: RefCounted


func before_all() -> void:
	catalog = PokemonDataScript.new()
	assert_true(catalog.load_catalog(), "Pokemon.json 应可加载")


func test_catalog_contains_national_dex() -> void:
	assert_eq(catalog.count(), 1025, "应包含 #0001-#1025 全国图鉴")
	var bulbasaur: Dictionary = catalog.get_entry(1)
	assert_eq(bulbasaur["name"], "妙蛙种子")
	assert_eq(bulbasaur["base_stat_total"], 318)
	assert_eq(bulbasaur["skills"].size(), 4, "每只宝可梦应有 4 个技能/特性")


func test_species_stats_drive_level_growth() -> void:
	var stats: Dictionary = catalog.stats_at_level(1, 50)
	assert_eq(stats["hp"], 115, "HP 应由种族 HP 换算")
	assert_eq(stats["attack"], 64, "攻击应由攻击种族值换算")
	assert_gt(catalog.combat_power(1, 50), catalog.combat_power(1, 10))


func test_search_supports_name_type_and_generation() -> void:
	var result: Array[Dictionary] = catalog.search("喷火龙", "fire", 1)
	assert_eq(result.size(), 1)
	assert_eq(result[0]["id"], 6)
	assert_eq(catalog.search("喷火龙", "water", 1).size(), 0)


func test_dual_type_effectiveness_multiplies() -> void:
	assert_almost_eq(catalog.type_multiplier("grass", ["water", "ground"]), 4.0, 0.001)
	assert_almost_eq(catalog.type_multiplier("electric", ["ground"]), 0.0, 0.001)


func test_three_member_battle_is_deterministic_with_seed() -> void:
	var simulator: RefCounted = BattleSimulatorScript.new(catalog, 42)
	var result: Dictionary = simulator.simulate([1, 4, 7], 30)
	assert_false(result.has("error"))
	assert_eq(result["rounds"].size(), 3)
	assert_gt(result["player_score"], 0)
