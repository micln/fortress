class_name MapRegistry
extends RefCounted

## 地图注册表
##
## 集中管理所有预设地图的定义和元信息，供地图选择界面和地图加载器使用。
## 支持按 ID 获取地图定义对象。

# === 单例 ===
static func get_instance() -> MapRegistry:
	if _instance == null:
		_instance = MapRegistry.new()
	return _instance

static var _instance: MapRegistry = null

# === 地图注册表 ===
var _maps: Dictionary = {}

func _init() -> void:
	_register_builtin_maps()


## 注册一张预设地图。
func register_map(map_id: String, definition: RefCounted) -> void:
	_maps[map_id] = definition


## 返回所有已注册地图的元信息列表，用于地图选择界面展示。
func get_all_map_summaries() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for map_id: String in _maps.keys():
		var def = _maps[map_id]
		var meta: Dictionary = def.get_metadata()
		summaries.append({
			"map_id": map_id,
			"name": meta.get("name", map_id),
			"supported_faction_counts": meta.get("supported_faction_counts", [2, 3, 4, 5]),
			"city_count": def.get_city_definitions().size()
		})
	return summaries


## 根据 ID 获取地图定义对象。
func get_map_definition(map_id: String) -> RefCounted:
	return _maps.get(map_id)


## 返回第一张可用地图的 ID（默认选择）。
func get_default_map_id() -> String:
	if _maps.is_empty():
		return ""
	var keys: Array = _maps.keys()
	return keys[0]


## 注册所有内置地图。
func _register_builtin_maps() -> void:
	# 第1关：新手演练（默认第一张）
	var level01 = preload("res://scripts/application/level_01_xin_shou.gd").new()
	_maps["level_01_xin_shou"] = level01

	# 第2关：入门之战
	var level02 = preload("res://scripts/application/level_02_ru_men.gd").new()
	_maps["level_02_ru_men"] = level02

	# 第3关：三角纷争
	var level03 = preload("res://scripts/application/level_03_san_jiao.gd").new()
	_maps["level_03_san_jiao"] = level03

	# 第4关：四方争雄
	var level04 = preload("res://scripts/application/level_04_si_fang.gd").new()
	_maps["level_04_si_fang"] = level04

	# 第5关：草莽崛起
	var level05 = preload("res://scripts/application/level_05_cao_mang.gd").new()
	_maps["level_05_cao_mang"] = level05

	# 第6关：逐鹿荆襄
	var level06 = preload("res://scripts/application/level_06_jing_xiang.gd").new()
	_maps["level_06_jing_xiang"] = level06

	# 第7关：逐鹿中原
	var level07 = preload("res://scripts/application/level_07_zhong_yuan.gd").new()
	_maps["level_07_zhong_yuan"] = level07

	# 第8关：群雄并起
	var level08 = preload("res://scripts/application/level_08_qun_xiong.gd").new()
	_maps["level_08_qun_xiong"] = level08

	# 第9关：天下大乱
	var level09 = preload("res://scripts/application/level_09_tian_xia.gd").new()
	_maps["level_09_tian_xia"] = level09

	# 第10关：一统天下
	var level10 = preload("res://scripts/application/level_10_tong_yi.gd").new()
	_maps["level_10_tong_yi"] = level10
