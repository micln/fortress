class_name GameHud
extends CanvasLayer

@onready var _status_label: Label = $TopPanel/StatusLabel
@onready var _detail_label: Label = $BottomPanel/DetailLabel


## 更新顶部状态文案，显示当前局势或胜负结果。
## 调用场景：开局、攻击后、每秒刷新后由主场景调用。
## 主要逻辑：根据传入字符串直接更新 HUD 标签。
func set_status(text: String) -> void:
	_status_label.text = text


## 更新底部提示文案，展示选中城市与操作说明。
## 调用场景：玩家选中城市、取消选中或结算后调用。
## 主要逻辑：根据当前交互上下文覆盖详情标签内容。
func set_detail(text: String) -> void:
	_detail_label.text = text
