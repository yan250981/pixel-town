extends CanvasLayer

## 游戏 HUD：左上操作提示、底部交互提示、底部对话框（支持多分支选项）。
##
## 只做展示，不持有任何游戏状态；数据全部来自 [Player] 的两个信号：
## [signal Player.prompt_changed] 与 [signal Player.interact_requested]。
##
## 对话有两档：
## * 普通交互点（招牌/告示栏）直接把 member Interactable.lines 一屏显示完；
## * NPC 带 dialogue_id 时，去 res://data/dialogues.json 找对话树，
##   按「正文 + 若干选项」逐节点推进。
## 对话打开期间 [Player] 会通过 "dialogue_ui" 组检测并冻结移动。

## 要监听的玩家节点路径（相对 HUD 自身），在 main.tscn 里绑定。
@export var player_path: NodePath = NodePath("../Entities/Player")
## 对话树数据文件，键 = NPC.dialogue_id。
@export_file("*.json") var dialogue_file: String = "res://data/dialogues.json"

@onready var _prompt: Label = $Prompt
@onready var _dialogue: PanelContainer = $Dialogue
@onready var _dialogue_title: Label = $Dialogue/Content/Title
@onready var _dialogue_body: Label = $Dialogue/Content/Body
@onready var _dialogue_options: VBoxContainer = $Dialogue/Content/Options

var _dialogue_open: bool = false
var _trees: Dictionary = {}
var _nodes: Dictionary = {}
var _current_options: Array = []
var _selected: int = 0


func _ready() -> void:
	add_to_group("dialogue_ui")
	_prompt.hide()
	_dialogue.hide()
	_trees = _load_dialogues()

	var player: Player = get_node_or_null(player_path) as Player
	if player == null:
		push_error("HUD: player_path 指向的节点不存在或不是 Player，交互提示与对话框不会显示。")
		return
	player.prompt_changed.connect(_on_prompt_changed)
	player.interact_requested.connect(_on_interact_requested)


## 读 JSON；文件缺失或格式错误时返回空字典，游戏仍能靠 lines 跑下去。
func _load_dialogues() -> Dictionary:
	if not FileAccess.file_exists(dialogue_file):
		push_warning("HUD: 找不到对话数据 %s，NPC 将退回单屏文本。" % dialogue_file)
		return {}
	var text: String = FileAccess.get_file_as_string(dialogue_file)
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("HUD: %s 不是合法的 JSON 对象。" % dialogue_file)
		return {}
	return data


func _unhandled_input(event: InputEvent) -> void:
	if not _dialogue_open:
		return
	if event.is_action_pressed(&"ui_cancel"):
		_close_dialogue()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"interact"):
		_choose(_selected)
		get_viewport().set_input_as_handled()
		return
	# 数字键 1~4 直选
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.keycode - KEY_1
		if index >= 0 and index < mini(4, _current_options.size()):
			_choose(index)
			get_viewport().set_input_as_handled()


## 进入/离开交互范围。提示为空即已走出范围，此时顺手收起对话框。
func _on_prompt_changed(prompt_text: String) -> void:
	_prompt.text = prompt_text
	_refresh_prompt_visibility()
	if prompt_text.is_empty():
		_close_dialogue()


func _on_interact_requested(target: Interactable) -> void:
	var npc: NPC = target as NPC
	if npc != null and not npc.dialogue_id.is_empty():
		var tree: Dictionary = _trees.get(npc.dialogue_id, {})
		if not tree.is_empty():
			_open_tree(npc, tree)
			return
	# 没有对话树：单屏显示
	_dialogue_title.text = target.title
	_dialogue_body.text = "\n".join(target.lines)
	_current_options.clear()
	_rebuild_options()
	_set_open(true)


## 进入对话树：读取节点表并从 start 开始。
func _open_tree(npc: NPC, tree: Dictionary) -> void:
	_nodes = tree.get("nodes", {})
	var start_id: String = str(tree.get("start", ""))
	if _nodes.is_empty() or not _nodes.has(start_id):
		_dialogue_title.text = npc.title
		_dialogue_body.text = "\n".join(npc.lines)
		_current_options.clear()
		_rebuild_options()
		_set_open(true)
		return
	_show_node(start_id)


## 渲染一个对话节点；next 为空代表对话结束。
func _show_node(node_id: String) -> void:
	if not _nodes.has(node_id):
		_close_dialogue()
		return
	var node: Dictionary = _nodes[node_id]
	_dialogue_title.text = str(node.get("speaker", _dialogue_title.text))
	_dialogue_body.text = str(node.get("text", ""))
	# 必须 duplicate：JSON 里的数组是引用类型，直接持有再 clear() 会把对话树本身清空
	_current_options = (node.get("options", []) as Array).duplicate()
	_selected = 0
	_rebuild_options()
	_set_open(true)


## 选项列表按需生成 Label，避免在场景里堆固定节点。
func _rebuild_options() -> void:
	# 立刻 remove_child 而不是只 queue_free：queue_free 要等本帧结束才真正生效，
	# 同一帧内连续 rebuild（比如 _show_node 紧跟 _set_open）会出现「新旧两批选项并存」。
	for child: Node in _dialogue_options.get_children():
		_dialogue_options.remove_child(child)
		child.queue_free()

	if _current_options.is_empty():
		_add_option_label("[Esc] 结束对话", true)
		return
	for i: int in _current_options.size():
		var option: Dictionary = _current_options[i]
		var prefix: String = "[%d] " % (i + 1)
		_add_option_label(prefix + str(option.get("text", "...")), i == _selected)


func _add_option_label(text: String, active: bool) -> void:
	var label: Label = Label.new()
	# 把「不带箭头」的原文存进 meta，切换选中项时用它重拼，
	# 不要用 substr 截前缀（"▶ " 和全角空格宽度不同，截错会越切越歪）。
	label.set_meta(&"plain_text", text)
	label.text = _option_line(text, active)
	label.add_theme_font_override("font", _dialogue_body.get_theme_font("font"))
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", _option_color(active))
	_dialogue_options.add_child(label)


## 选中项加 ▶ 前缀。未选中用全角空格（U+3000）+ 半角空格对齐，
## 两者的字形宽度与 "▶ " 一致，切换选中时文字不会左右跳。
func _option_line(text: String, active: bool) -> String:
	return ("▶ " if active else "　 ") + text


func _move_selection(delta: int) -> void:
	if _current_options.size() <= 1:
		return
	_selected = wrapi(_selected + delta, 0, _current_options.size())
	# 只改文字与颜色，不重建节点，避免反复 queue_free / add_child
	for i: int in _dialogue_options.get_child_count():
		var label: Label = _dialogue_options.get_child(i) as Label
		if label == null:
			continue
		var active: bool = i == _selected
		label.text = _option_line(str(label.get_meta(&"plain_text", "")), active)
		label.add_theme_color_override("font_color", _option_color(active))


## 选中项高亮、未选中项压暗。
func _option_color(active: bool) -> Color:
	return Color(1.0, 0.85, 0.44) if active else Color(0.78, 0.75, 0.69)


func _choose(index: int) -> void:
	if _current_options.is_empty():
		_close_dialogue()
		return
	if index < 0 or index >= _current_options.size():
		return
	var option: Dictionary = _current_options[index]
	var next_id: String = str(option.get("next", ""))
	if next_id.is_empty():
		_close_dialogue()
		return
	_show_node(next_id)


func _set_open(open: bool) -> void:
	_dialogue_open = open
	_dialogue.visible = open
	if open:
		_fit_dialogue_soon()
	_refresh_prompt_visibility()


## 等一帧再量高度：新加的选项 Label 还没参与布局，立刻量会拿到「宽度 0」的换行高度。
func _fit_dialogue_soon() -> void:
	await get_tree().process_frame
	if _dialogue_open:
		_fit_dialogue()


## 面板贴底、高度跟着内容走：选项少时不留大片空白。
func _fit_dialogue() -> void:
	var min_height: float = _dialogue.get_combined_minimum_size().y
	var height: float = clampf(min_height, 120.0, 430.0)
	_dialogue.offset_top = _dialogue.offset_bottom - height


func _close_dialogue() -> void:
	_dialogue_open = false
	_dialogue.visible = false
	_current_options.clear()
	_refresh_prompt_visibility()


## 提示条只在「范围内」且「对话框没开」时显示，避免两处 UI 同时抢注意力。
func _refresh_prompt_visibility() -> void:
	_prompt.visible = not _prompt.text.is_empty() and not _dialogue_open


## 给 Player 用来冻结移动：对话打开时不允许走动。
func is_dialogue_open() -> bool:
	return _dialogue_open
