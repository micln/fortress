class_name PrototypeCityOwner
extends RefCounted

const NEUTRAL: int = 0
const PLAYER: int = 1
const AI_OWNER_START: int = 2
const OWNER_COLORS: Array[Color] = [
	Color("ff6b6b"),
	Color("ffb347"),
	Color("4ecdc4"),
	Color("c77dff"),
	Color("f28482"),
	Color("90be6d")
]


## 判断一个归属编号是否代表玩家。
##
## 调用场景：输入选择校验、胜负判断、AI 目标偏好。
## 主要逻辑：玩家固定使用编号 1，方便在多 AI 势力下保持唯一性。
static func is_player(owner: int) -> bool:
	return owner == PLAYER


## 判断一个归属编号是否代表中立城市。
##
## 调用场景：产兵、地图初始化、胜负判断。
## 主要逻辑：编号 0 为唯一中立标识，其余均视为某个势力。
static func is_neutral(owner: int) -> bool:
	return owner == NEUTRAL


## 判断一个归属编号是否代表电脑 AI 势力。
##
## 调用场景：AI 回合调度、HUD 展示、胜负结算。
## 主要逻辑：所有大于等于 2 的编号都视为独立 AI 势力。
static func is_ai(owner: int) -> bool:
	return owner >= AI_OWNER_START


## 返回所有仍占领至少一座城市的非中立势力编号。
##
## 调用场景：胜负判断、AI 轮转调度。
## 主要逻辑：遍历城市列表去重收集所有占领势力，并按编号排序输出，方便调用层做稳定处理。
static func get_active_owners(cities: Array) -> Array[int]:
	var owners: Array[int] = []
	for city in cities:
		if is_neutral(city.owner) or owners.has(city.owner):
			continue
		owners.append(city.owner)
	owners.sort()
	return owners


## 返回阵营对应的展示颜色，供表现层统一渲染城市和道路。
##
## 调用场景：城市节点刷新外观、道路绘制、行军单位渲染。
## 主要逻辑：玩家固定使用蓝色，中立使用灰色，其余 AI 势力按调色板循环分配颜色。
static func get_color(owner: int) -> Color:
	if is_neutral(owner):
		return Color("8b95a5")
	if is_player(owner):
		return Color("4d9fff")
	var color_index: int = max(0, owner - AI_OWNER_START) % OWNER_COLORS.size()
	return OWNER_COLORS[color_index]


## 返回阵营对应的人类可读名称，供 UI 状态提示使用。
##
## 调用场景：顶部状态栏、开始/结束面板、调试信息。
## 主要逻辑：玩家和中立走固定文案，其余 AI 势力根据编号自动生成“电脑X”名称。
static func get_owner_name(owner: int) -> String:
	if is_neutral(owner):
		return "中立"
	if is_player(owner):
		return "玩家"
	return "电脑%d" % (owner - AI_OWNER_START + 1)
