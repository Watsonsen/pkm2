# Pokemon Expedition / 宝可梦远征

基于 [CardGame2](https://github.com/wgt19861219/CardGame2) 的 Godot 4.7 宝可梦编队卡牌游戏原型。项目保留了脚手架的 View / Logic / Data 三层设计，将原英雄体系替换为 1–1025 全国图鉴。

## 已实现

- 1025 只宝可梦的中英文名称、世代、属性、进化链、图鉴文本和官方立绘。
- 六项种族值取代原游戏的 `+STR/+AGI/+INT` 星级成长表，按等级动态换算战斗属性。
- 每只宝可梦 4 项专属设计：终结技、主属性主动技、副属性/定位战术、种族特性。
- 根据双攻、耐久和速度自动判定「物理输出 / 特殊输出 / 守护壁垒 / 先手攻坚 / 均衡输出」。
- 支持名称、英文名、编号、属性、世代筛选，以及 3 人远征队编成。
- 战斗模拟会同时计算等级属性、战力波动与 18 属性克制。

## 启动

1. 安装 Godot 4.7（标准版）。
2. 用 Godot 打开本目录下的 `project.godot`。
3. 等待首次资源导入完成，按 F6/F5 运行。

## 重建图鉴数据

项目内置的生成器只读本地 HTML 和立绘，不访问网络：

```powershell
python tools/pokemon/build_pokemon_catalog.py `
  --html "C:\path\to\pokedex_all.html" `
  --artwork "C:\path\to\artwork" `
  --output "resources/data/Pokemon.json" `
  --artwork-output "assets/pokemon/artwork"
```

## 数据与分层

- `resources/data/Pokemon.json` — 1025 只宝可梦及 4100 项技能/特性。
- `scripts/data/pokemon_data.gd` — 图鉴查询、等级属性和属性相性。
- `scripts/systems/pokemon_battle_simulator.gd` — 无 UI 依赖的对战逻辑。
- `scenes/hero/hero_scene.gd` — 图鉴、详情、编队和对战界面。
- `tools/pokemon/build_pokemon_catalog.py` — 可重复的数据/立绘构建工具。
- `tests/test_pokemon_data.gd` — 图鉴完整性、种族值成长、检索、克制和对战测试。

## 版权说明

本项目是个人学习与原型验证项目。Pokémon 及相关美术、名称的权利归其各自权利人所有；请勿将本项目中的受保护素材用于未经授权的商业发行。
