class_name Player
extends CharacterBody2D

## 玩家角色控制器。
##
## 职责：读取移动输入 → 加速/减速 → 移动 → 切换走路/待机动画并翻转水平朝向；
## 另外负责检测身边的 [Interactable]，把「有东西可以交互」与「玩家按下了交互键」
## 两件事通过信号抛给 UI，本身不直接引用任何 UI 节点。
##
## 贴图为正面偏左的 3/4 视角像素画（12 帧行走 + 1 帧站立待机，12fps），
## 向左移动时通过 [member AnimatedSprite2D.flip_h] 镜像，向上/向下移动时沿用上一次的水平朝向。
## 节点原点位于角色脚下（脚底），便于贴地与碰撞体对齐。

## 进入/离开交互范围时发出，参数为空字符串表示隐藏提示。
signal prompt_changed(prompt_text: String)

## 玩家按下交互键且当前有目标时发出，UI 负责显示 [param target] 的内容。
signal interact_requested(target: Interactable)

@export_group("Movement")
## 最大移动速度（像素/秒）。
@export var max_speed: float = 240.0
## 有输入时的加速度（像素/秒²），数值越大起步越干脆。
@export var acceleration: float = 2200.0
## 无输入时的减速度（像素/秒²）。
@export var friction: float = 2600.0
## 角色可活动范围，默认覆盖整张地图，超出后会被夹住。
@export var walk_bounds: Rect2 = Rect2(0.0, 0.0, 1732.0, 973.0)

@export_group("Animation")
## 移动时播放的动画名（需存在于 SpriteFrames 中）。
@export var walk_animation: StringName = &"walk"
## 静止时播放的动画名。
@export var idle_animation: StringName = &"idle"
## 美术资源自带的朝向：true = 原图朝左，false = 原图朝右。
## 当前主角图（灰卫衣少女）是朝左的 3/4 视角，所以「向左走不翻转、向右走才翻转」；
## 换成朝右的素材时把这个开关反过来即可，不用改逻辑。
@export var art_faces_left: bool = true

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _interact_area: Area2D = $InteractArea

var _facing_left: bool = false
var _nearby_interactables: Array[Interactable] = []
var _active_interactable: Interactable = null


func _ready() -> void:
	_interact_area.area_entered.connect(_on_interact_area_entered)
	_interact_area.area_exited.connect(_on_interact_area_exited)
	# 开局朝向直接沿用素材本身的朝向：先给出一次水平输入之前，人物保持原图不镜像
	_facing_left = art_faces_left
	_sprite.flip_h = false


func _unhandled_input(event: InputEvent) -> void:
	if _active_interactable == null or _is_dialogue_open():
		return
	if event.is_action_pressed(&"interact"):
		interact_requested.emit(_active_interactable)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	# 对话期间冻结移动：方向键要留给选项导航
	if _is_dialogue_open():
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		return

	var input_direction: Vector2 = Input.get_vector(
		&"move_left", &"move_right", &"move_up", &"move_down"
	)
	var target_speed: float = max_speed if input_direction != Vector2.ZERO else 0.0
	var rate: float = acceleration if input_direction != Vector2.ZERO else friction
	velocity = velocity.move_toward(input_direction * target_speed, rate * delta)

	move_and_slide()
	_clamp_to_bounds()
	_update_animation(input_direction)


## 把角色夹在地图范围内，避免走出背景图边缘。
func _clamp_to_bounds() -> void:
	global_position = global_position.clamp(walk_bounds.position, walk_bounds.end)


## 根据输入方向切换动画与朝向。只在动画变化时调用 play，避免每帧重置动画。
func _update_animation(input_direction: Vector2) -> void:
	if absf(input_direction.x) > 0.01:
		_facing_left = input_direction.x < 0.0
	# 贴图本身朝左：向左走保持原图，向右走才镜像。
	# 写成「异或」而不是直接赋值，是为了让上面的 art_faces_left 开关能一键反转朝向。
	_sprite.flip_h = _facing_left != art_faces_left

	var wanted_animation: StringName = (
		walk_animation if input_direction != Vector2.ZERO else idle_animation
	)
	if _sprite.animation != wanted_animation:
		_sprite.play(wanted_animation)


func _on_interact_area_entered(area: Area2D) -> void:
	var target: Interactable = area as Interactable
	if target == null or _nearby_interactables.has(target):
		return
	_nearby_interactables.append(target)
	_refresh_active_interactable()


func _on_interact_area_exited(area: Area2D) -> void:
	var target: Interactable = area as Interactable
	if target == null:
		return
	_nearby_interactables.erase(target)
	_refresh_active_interactable()


## 在范围内的交互点中选最近的一个作为当前目标，变化时才发信号。
func _refresh_active_interactable() -> void:
	var nearest: Interactable = null
	var nearest_distance: float = INF
	for target: Interactable in _nearby_interactables:
		var distance: float = global_position.distance_squared_to(target.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = target

	if nearest == _active_interactable:
		return
	_active_interactable = nearest
	prompt_changed.emit("" if nearest == null else nearest.get_prompt())


## HUD 是否正开着对话框（HUD 在 "dialogue_ui" 组里）。用 call 避免硬依赖 UI 类型。
func _is_dialogue_open() -> bool:
	var ui: Node = get_tree().get_first_node_in_group(&"dialogue_ui")
	if ui == null:
		return false
	return bool(ui.call(&"is_dialogue_open"))
