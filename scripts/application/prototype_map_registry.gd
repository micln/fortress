class_name PrototypeMapRegistry
extends RefCounted

## 地图注册表
##
## 集中管理所有预设地图的定义和元信息，供地图选择界面和地图加载器使用。
## 支持按 ID 获取地图定义对象。

# === 单例 ===
static func get_instance() -> PrototypeMapRegistry:
	if _instance == null:
		_instance = PrototypeMapRegistry.new()
	return _instance

static var _instance: PrototypeMapRegistry = null

# === 地图注册表 ===
var _maps: Dictionary = {}

func _init() -> void:
	_register_builtin_maps()


## 注册一张预设地图。
func register_map(map_id: String, definition: PrototypePresetMapDefinition) -> void:
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
	# 中原风云（默认第一张）
	var central_plains: PrototypePresetMapDefinition = preload("res://scripts/application/prototype_preset_map_definition.gd").new()
	_maps["china_central_plains_v1"] = central_plains

	# 江东风云
	var jiangdong = preload("res://scripts/application/prototype_map_jiangdong.gd").new()
	_maps["jiangdong_v1"] = jiangdong

	# 荆襄风云
	var jingxiang = preload("res://scripts/application/prototype_map_jingxiang.gd").new()
	_maps["jingxiang_v1"] = jingxiang
