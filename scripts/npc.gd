class_name NPC
extends Interactable

## 会说话的 NPC。
##
## 在 [Interactable] 的基础上多一个 [member dialogue_id]：如果它指向
## data/dialogues.json 里的一棵树，HUD 会打开带选项的对话；
## 找不到对应数据时退化成普通的一屏文本（member Interactable.lines）。

## 对话树 id，对应 res://data/dialogues.json 顶层的键；留空表示只用 lines。
@export var dialogue_id: String = ""

## 贴图默认朝右，设为 true 时水平翻转。
@export var facing_left: bool = false

@onready var _sprite: Sprite2D = get_node_or_null(^"Sprite") as Sprite2D


func _ready() -> void:
	# 没有贴图节点的 NPC（纯逻辑交互点）也允许存在，不要因此报 null 错误
	if _sprite != null:
		_sprite.flip_h = facing_left
