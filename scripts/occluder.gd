extends Sprite2D

## 建筑前景遮挡层。
##
## 每个 Overlay_* 都是同一张地图纹理按 region 裁出的建筑底部条带，排序锚点
## 放在建筑底部线上（[member Node2D.position].y），因此在 Entities 的 Y 排序里，
## 只要玩家 y 小于这条线，玩家就会先被绘制、再被这一层盖住 —— 形成「走到房子后面」。
##
## 代价是玩家会完全看不见自己，所以这里再做一件事：玩家躲进这层背后时
## 把 alpha 降下去，透出自己的轮廓，避免「人丢了」的操作困惑。

## 玩家节点（相对本节点），Overlay 与 Player 同为 Entities 的子节点。
@export var player_path: NodePath = NodePath("../Player")
## 玩家躲在后面时的不透明度：0 完全隐藏，1 完全实心。
## 因为可进入条带只有 24px，头顶始终会露出墙面，所以这里只轻微淡出，避免「人丢了」。
@export_range(0.0, 1.0) var hidden_alpha: float = 0.85
## 淡入淡出速度（每秒变化量）。
@export var fade_speed: float = 6.0

var _player: Node2D = null
var _base_alpha: float = 1.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	_base_alpha = modulate.a


func _process(delta: float) -> void:
	var target: float = _base_alpha
	if _is_player_behind():
		target = _base_alpha * hidden_alpha
	modulate.a = move_toward(modulate.a, target, fade_speed * delta)


## 玩家是否落在本层的绘制矩形内、且在排序线之上。
##
## 条带 = 节点原点 + offset 起、边长 = region 尺寸的矩形（Sprite2D 非居中时
## 绘制起点就是 offset）；矩形下边正好落在节点原点上，也就是 Y 排序线。
## 全程用 global 坐标比较：万一以后把 Entities 整体挪了位置，这里不会错位。
func _is_player_behind() -> bool:
	if _player == null:
		return false
	var strip_position: Vector2 = global_position + offset
	var strip_size: Vector2 = region_rect.size
	var p: Vector2 = _player.global_position
	return (
		p.y <= strip_position.y + strip_size.y
		and p.y >= strip_position.y
		and p.x >= strip_position.x
		and p.x <= strip_position.x + strip_size.x
	)
