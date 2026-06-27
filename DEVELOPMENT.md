# Math Knight Development

本文档面向开发者，说明 Math Knight 的运行、构建、配置和资源维护流程。玩家向说明见 [README.md](README.md)。

## 项目配置

- 引擎版本：Godot v4.3。
- 显示名：`Math Knight`。
- Godot 应用用户目录：`math-knight`。
- 主场景：`scenes\Main.tscn`。
- 主逻辑：`scripts\Main.gd`。
- 难度配置：`assets\config\series_options.json`。

`project.godot` 中启用了自定义用户目录：

```ini
config/name="Math Knight"
config/use_custom_user_dir=true
config/custom_user_dir_name="math-knight"
```

运行时数据文件：

- `user://math_knight_players.json`
- `user://math_knight_stats.json`

## 运行

使用 Godot v4.3 打开项目根目录，或通过脚本启动：

```powershell
.\actions\open-godot.ps1
```

`actions\open-godot.ps1` 默认设置 `MATH_WAR_BOSS_HP=5`，便于本地调试快速结束战斗。正式默认 Boss 生命值在代码中为 20。

## Boss HP 调试参数

运行时 Boss 最大生命值读取顺序：

1. Web URL 参数 `MATH_WAR_BOSS_HP`
2. 桌面环境变量 `MATH_WAR_BOSS_HP`
3. 代码默认值 `BOSS_MAX_HP = 20`

Web 示例：

```text
http://localhost:9090/apps/web/?MATH_WAR_BOSS_HP=5
```

桌面示例：

```powershell
$env:MATH_WAR_BOSS_HP = "5"
& $env:GODOT_EXE --path .
```

## 构建

先在 Godot 中安装 v4.3 导出模板：`Editor -> Manage Export Templates`。脚本会检查 Godot 默认模板目录和 Godot 可执行文件旁的 `editor_data\export_templates` 目录。

构建全部目标：

```powershell
.\actions\build.ps1 -GodotPath $env:GODOT_EXE
```

只构建 HTML5：

```powershell
.\actions\build.ps1 -Target HTML5 -GodotPath $env:GODOT_EXE
```

只构建 Windows：

```powershell
.\actions\build.ps1 -Target Windows -GodotPath $env:GODOT_EXE
```

如果模板版本目录不同：

```powershell
.\actions\build.ps1 -GodotPath $env:GODOT_EXE -TemplateVersion "4.3.stable"
```

如果模板在自定义目录：

```powershell
.\actions\build.ps1 -GodotPath $env:GODOT_EXE -TemplateRoot "path\to\export_templates"
```

输出目录：

- HTML5: `dist\web\index.html`
- Windows: `dist\win\index.exe`

## 难度配置

难度数据由 `assets\config\series_options.json` 提供，代码中没有内置兜底列表。配置必须是数组，元素格式为：

```json
{ "key": "L01", "name": "凑五法", "op": "make_five" }
```

- `key`：稳定记录键，用于历史统计匹配。
- `name`：首页展示名称。
- `op`：题目生成器标识，对应 `scripts\Main.gd` 中的生成逻辑。

导出配置通过 `export_presets.cfg` 的 `include_filter="assets/config/*.json"` 将 JSON 配置打包进导出版本。

## 资源目录

可编辑源素材放在 `resources` 下，Godot 运行时资源放在 `assets` 下。`resources\.gdignore` 会阻止 Godot 导入源文件。

像素图源文件：

```text
resources\pixelorama
```

导出的 Godot PNG：

```text
assets\sprites
```

图标 SVG 源文件：

```text
resources\icons
```

导出的 Godot 图标 PNG：

```text
assets\icons
```

## 图标导出

从 SVG 源文件导出图标 PNG：

```powershell
.\actions\export-icons.ps1
```

指定 Godot 路径和尺寸：

```powershell
.\actions\export-icons.ps1 -GodotPath $env:GODOT_EXE -Size 32
```

导出逻辑在 `tools\export_icons.gd` 中。脚本会将 SVG 填充色归一为白色，运行时再由 Godot 通过 `modulate` 着色。

## Pixelorama 导出

从 Pixelorama 源文件导出 PNG：

```powershell
.\actions\export-pixelorama.ps1
```

默认以 4 倍尺寸导出。调整倍率：

```powershell
.\actions\export-pixelorama.ps1 -Scale 2
```

脚本会优先使用 `-PixeloramaPath`，其次使用 `PIXELORAMA_EXE` 环境变量，再从 `PATH` 查找 `Pixelorama.exe`。如果 Pixelorama 命令行导出没有生成文件，脚本会使用 Godot 读取 `.pxo` 像素数据作为 fallback。

## Web 部署

构建完成后，将 `dist\web` 下的全部内容拷贝到本地 HTTP 服务根目录对应位置（例如 `apps\web`），随后即可通过 `http://localhost:9090/apps/web/` 访问：

```powershell
$HttpRoot = "C:\path\to\http\root"
Copy-Item -Path .\dist\web\* -Destination (Join-Path $HttpRoot "apps\web") -Recurse -Force
```
