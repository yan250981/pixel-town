# 像素小镇 · Pixel Town

一个用 **Godot 4.7** 做的 2D 像素风小镇探索小游戏。操控少女在小镇石板路上自由走动，和渔夫、商人聊天，走进建筑背后会被房子挡住，海边和树木都走不过去。

## 玩法

| 操作 | 按键 |
|---|---|
| 移动 | `W` `A` `S` `D` 或 `↑` `↓` `←` `→` |
| 交互 / 对话 | `空格` 或 `E` |
| 对话中切换选项 | `↑` `↓` |
| 对话中确认 | `空格` / `E` |
| 直接选第 N 项 | 数字键 `1`~`4` |
| 关闭对话 | `Esc` |

地图上有两个 NPC（渔夫、商人）和几个可交互物件（告示栏等）。走到旁边头顶会出现提示，按键即可展开分支对话，不同选项会走到不同的对话节点。

## 技术要点

- **角色动画**：`AnimatedSprite2D` + `SpriteFrames`，12 帧行走循环 @12fps，1 帧待机。素材是正面偏左的 3/4 视角，靠 `flip_h` 镜像区分左右朝向（`player.gd` 里用 `art_faces_left` 开关控制，换素材不用改逻辑）。
- **碰撞**：整张地图用 16px 网格反推碰撞矩形——海水 31 个、建筑 14 个、树干 7 个圆形，碰撞体与美术像素完整贴合。
- **深度遮挡**：`y_sort_enabled` 负责一般排序；对建筑额外用一张 `region` 裁切的 Overlay 盖在玩家上层，玩家走进建筑底部条带时 `occluder.gd` 把它淡到 `alpha 0.85`，实现"走到房子后面被挡住、又能看见人"。
- **交互系统**：`Interactable`（Area2D，layer 2）通过信号 `prompt_changed` / `interact_requested` 与 HUD 解耦，玩家不直接引用任何 UI 节点。
- **对话树**：`data/dialogues.json` 存 `{speaker, text, options:[{text, next}]}`，HUD 负责状态机与选项渲染。
- **中文字体**：`art/ui_font.tres` 用 `SystemFont` 回退链（微软雅黑 → 黑体 → 苹方 → Noto CJK），避免打包体积膨胀。

## 目录结构

```
art/          地图、角色帧集、NPC、字体资源
data/         对话树 dialogues.json
scenes/       main.tscn（世界）/ player.tscn / hud.tscn
scripts/      player.gd / hud.gd / interactable.gd / npc.gd / occluder.gd
export_presets.cfg   Windows 导出配置（单文件 exe）
project.godot
```

## 本地运行

1. 安装 [Godot 4.7](https://godotengine.org/download)（标准版，无需 .NET）
2. 用 Godot 打开本目录下的 `project.godot`
3. 按 `F5` 运行

首次打开会自动导入资源。渲染后端用的是 `gl_compatibility`，老显卡和核显都能跑。

## 导出成 exe 发给别人

先在编辑器里装好导出模板（编辑器 → 管理导出模板），然后：

```bash
mkdir -p build
godot --headless --path . --export-release "Windows Desktop" "build/PixelTown.exe"
```

`embed_pck=true` 已开启，产出的就是单个 exe，对方双击即玩，不需要装 Godot。测试过 Windows 10/11 64 位。

## 素材说明

- 地图 `art/main_map.jpg`、主角 `art/player_sheet.png`、NPC 由项目作者提供/生成。
- 代码部分可自由参考复用。

## 已知限制

- 主角只有一套行走帧，没有背面/侧面朝向，向上走时仍显示 3/4 正面。
- 树冠不做遮挡（需要单独抠图），现在是从树旁边绕过去。
- 门楼、石阶、码头没有碰撞，可以走到牌楼顶上。
