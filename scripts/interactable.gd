class_name Interactable
extends Area2D

## 场景中的可交互点（招牌、摊位、告示牌、NPC）。
##
## 本身不处理输入：玩家身上的 InteractArea 检测到它进入范围后，
## 由 Player 发出 [signal Player.prompt_changed]，玩家按下交互键时
## Player 再发出 [signal Player.interact_requested] —— UI 只负责显示，
## 交互点只负责“我是谁、我有什么内容”。
##
## 物理层：放在第 2 层（值 2），玩家的 InteractArea 只扫描这一层，
## 因此不会和角色/建筑的碰撞层互相干扰。

## 交互内容。标题显示在对话框顶部，[member lines] 逐行显示。
@export_multiline var lines: PackedStringArray = PackedStringArray(["这里什么都没有。"])
## 交互对象名，用于提示文本，例如「饭馆」。
@export var title: String = "告示牌"
## 提示动词，例如「查看」「品尝」「打听」。
@export var prompt_verb: String = "查看"


## 生成给 UI 显示的提示文本，例如「[空格] 查看 饭馆」。
func get_prompt() -> String:
	return "[空格] %s %s" % [prompt_verb, title]
