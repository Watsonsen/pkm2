#!/usr/bin/env python3
"""Build the in-game Pokémon catalog from the supplied offline Pokédex.

The source HTML contains a single `var POKEMON = [...]` assignment.  This
script deliberately reads only that embedded JSON and the numbered artwork
files; it never fetches data from the network.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from PIL import Image


TYPE_DESIGN = {
    "normal": ("一般", "共鸣冲击", "坚韧"),
    "fire": ("火", "烈焰轰击", "燃烧"),
    "water": ("水", "潮汐奔涌", "润泽"),
    "electric": ("电", "超载雷击", "感电"),
    "grass": ("草", "翠叶风暴", "生息"),
    "ice": ("冰", "极寒碎击", "冻结"),
    "fighting": ("格斗", "斗魂连打", "破防"),
    "poison": ("毒", "剧毒爆发", "中毒"),
    "ground": ("地面", "大地震荡", "迟缓"),
    "flying": ("飞行", "暴风俯冲", "浮空"),
    "psychic": ("超能力", "心灵震爆", "干扰"),
    "bug": ("虫", "群虫突袭", "蚀甲"),
    "rock": ("岩石", "岩峰坠落", "碎甲"),
    "ghost": ("幽灵", "幽冥奇袭", "恐惧"),
    "dragon": ("龙", "龙星裂空", "威压"),
    "dark": ("恶", "暗影猎杀", "虚弱"),
    "steel": ("钢", "钢铁终结", "护甲"),
    "fairy": ("妖精", "星光奇迹", "祝福"),
}
STAT_CN = {
    "hp": "HP",
    "attack": "攻击",
    "defense": "防御",
    "sp_atk": "特攻",
    "sp_def": "特防",
    "speed": "速度",
}


def extract_catalog(html_path: Path) -> list[dict]:
    text = html_path.read_text(encoding="utf-8")
    match = re.search(r"\bvar\s+POKEMON\s*=\s*(\[.*?\]);\s*\n", text, re.S)
    if not match:
        raise ValueError(f"POKEMON JSON was not found in {html_path}")
    data = json.loads(match.group(1))
    if len(data) != 1025:
        raise ValueError(f"expected 1025 Pokémon, found {len(data)}")
    return data


def combat_role(stats: dict[str, int]) -> str:
    offense = max(stats["attack"], stats["sp_atk"])
    bulk = stats["hp"] + stats["defense"] + stats["sp_def"]
    if stats["speed"] >= max(offense, stats["defense"], stats["sp_def"]):
        return "先手攻坚"
    if bulk >= 300:
        return "守护壁垒"
    if stats["sp_atk"] >= stats["attack"] + 12:
        return "特殊输出"
    if stats["attack"] >= stats["sp_atk"] + 12:
        return "物理输出"
    return "均衡输出"


def target_for(role: str) -> str:
    return "enemy_lowest_hp" if role == "先手攻坚" else "enemy_front"


def make_skills(pokemon: dict) -> list[dict]:
    stats = pokemon["stats"]
    role = combat_role(stats)
    primary = TYPE_DESIGN[pokemon["types"][0]]
    secondary_key = pokemon["types"][1] if len(pokemon["types"]) > 1 else pokemon["types"][0]
    secondary = TYPE_DESIGN[secondary_key]
    special = stats["sp_atk"] >= stats["attack"]
    power_stat = "sp_atk" if special else "attack"
    defense_stat = "sp_def" if special else "defense"
    total = pokemon["total"]
    return [
        {
            "slot": 1,
            "name": f"{pokemon['name']}·极限{primary[1]}",
            "kind": "ultimate",
            "type": pokemon["types"][0],
            "target": "enemy_all",
            "power": 88 + total // 16,
            "scales_with": power_stat,
            "effect": primary[2],
            "description": f"释放{pokemon['name']}的{primary[0]}属性本能，对全体敌人造成{primary[0]}属性伤害并附加【{primary[2]}】。",
        },
        {
            "slot": 2,
            "name": f"{pokemon['name']}·{primary[1]}",
            "kind": "active",
            "type": pokemon["types"][0],
            "target": target_for(role),
            "power": 42 + max(stats["attack"], stats["sp_atk"]) // 3,
            "scales_with": power_stat,
            "effect": primary[2],
            "description": f"以{STAT_CN[power_stat]}为主属性发动突击，并施加【{primary[2]}】。",
        },
        {
            "slot": 3,
            "name": f"{pokemon['name']}·{secondary[0]}战术",
            "kind": "active",
            "type": secondary_key,
            "target": "ally_lowest_hp" if role == "守护壁垒" else "enemy_highest_power",
            "power": 28 + max(stats["defense"], stats["sp_def"], stats["speed"]) // 4,
            "scales_with": defense_stat if role == "守护壁垒" else power_stat,
            "effect": secondary[2],
            "description": f"依据【{role}】定位执行{secondary[0]}属性战术，触发【{secondary[2]}】。",
        },
        {
            "slot": 4,
            "name": f"种族特性·{pokemon['name']}",
            "kind": "passive",
            "type": "passive",
            "target": "self",
            "power": 5 + total // 60,
            "scales_with": max(stats, key=stats.get),
            "effect": role,
            "description": f"基于种族值总和 {total} 的【{role}】特性；战斗中强化最高的{STAT_CN[max(stats, key=stats.get)]}属性。",
        },
    ]


def level_stats(stats: dict[str, int], level: int = 1) -> dict[str, int]:
    # Deterministic neutral-nature preview. Species base stats are the growth
    # source; fixed IV=20 keeps the card game readable and reproducible.
    iv = 20
    hp = ((2 * stats["hp"] + iv) * level) // 100 + level + 10
    result = {"hp": hp}
    for field in ("attack", "defense", "sp_atk", "sp_def", "speed"):
        result[field] = ((2 * stats[field] + iv) * level) // 100 + 5
    return result


def build_entry(pokemon: dict) -> dict:
    stats = pokemon["stats"]
    return {
        "id": pokemon["id"],
        "dex_no": f"#{pokemon['id']:04d}",
        "name": pokemon["name"],
        "en": pokemon["en"],
        "generation": pokemon["gen_id"],
        "types": pokemon["types"],
        "types_cn": pokemon["types_cn"],
        "genus": pokemon["genus"],
        "flavor": pokemon["flavor"],
        "height": pokemon["height"],
        "weight": pokemon["weight"],
        "capture_rate": pokemon["capture_rate"],
        "base_stats": stats,
        "preview_stats": level_stats(stats),
        "base_stat_total": pokemon["total"],
        "role": combat_role(stats),
        "rarity": "mythical" if pokemon["is_mythical"] else "legendary" if pokemon["is_legendary"] else "standard",
        "evolution": pokemon["evolution"],
        "artwork": f"res://assets/pokemon/artwork/{pokemon['id']:04d}.webp",
        "skills": make_skills(pokemon),
    }


def convert_artwork(source: Path, destination: Path, size: int) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    for source_file in sorted(source.glob("*.png")):
        number = int(source_file.stem)
        output_file = destination / f"{number:04d}.webp"
        with Image.open(source_file) as image:
            image = image.convert("RGBA")
            image.thumbnail((size, size), Image.Resampling.LANCZOS)
            canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            canvas.alpha_composite(image, ((size - image.width) // 2, (size - image.height) // 2))
            canvas.save(output_file, "WEBP", quality=84, method=6)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--html", required=True, type=Path)
    parser.add_argument("--artwork", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--artwork-output", required=True, type=Path)
    parser.add_argument("--size", type=int, default=256)
    parser.add_argument("--skip-artwork", action="store_true")
    args = parser.parse_args()

    source = extract_catalog(args.html)
    catalog = {str(item["id"]): build_entry(item) for item in source}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(catalog, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    if not args.skip_artwork:
        convert_artwork(args.artwork, args.artwork_output, args.size)
    print(f"generated {len(catalog)} Pokémon entries and {len(list(args.artwork_output.glob('*.webp')))} artworks")


if __name__ == "__main__":
    main()
