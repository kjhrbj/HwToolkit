---
name: hw-api-doc-query
description: 'Use when: 编写 / 修改 HyperWorks（HyperMesh / HyperView）Tcl 二次开发脚本，需要查询官方 API 文档'
user-invocable: true
---

# HyperWorks API 文档查询（HelpDocforAi）

查询 HyperMesh / HyperView 官方 Tcl 二次开发 API 文档。文档位于本工程 `HelpDocforAi/`，是 Altair HyperWorks 官方帮助的 Markdown 提取版，按命令名检索**语法、参数、示例**，并可查询各实体类型的**可读写数据名（Data Names）** 与 HyperView 的**类结构和方法**。

## 何时使用（When to Use）

- 编写 / 修改 HyperMesh 或 HyperView 的 Tcl 脚本，需要某条命令的语法、参数、示例
- 需要查询某实体类型（节点、单元、材料、属性、连接器…）可查询 / 可操作的 Data Names
- 需要了解 HyperView 的类结构、某类的方法列表，或某命令属于哪个类
- 某条旧命令在当前版本失效，需要找替代命令

### 先判断目标软件

| 目标 | 定位 | 文档目录 |
| --- | --- | --- |
| HyperMesh（建模 / 网格 / 几何 / 材料 / 连接器…） | `*` 或 `hm_` 命令、实体数据名 | `HelpDocforAi/hm_help/` |
| HyperView（后处理 / 云图 / 结果 / 视图 / 标注…） | `poI*` / `hwI*` 类与方法 | `HelpDocforAi/hv_help/` |

> 官方文档中的 *database* 指 HyperMesh 软件内部维护的模型数据（节点、单元、几何、材料等），即「软件内的有限元模型数据」，**并非关系型数据库**。

## 文档结构总览

```text
HelpDocforAi/
├── hm_help/                 # HyperMesh Tcl API（2957 篇）
│   ├── README.md            #   总览与导航
│   ├── _index/              #   分类总索引（表格）
│   │   ├── modify.md        #     → modify/（1991 篇，* 修改命令）
│   │   ├── query.md         #     → query/（641 篇，hm_ 查询命令）
│   │   ├── gui.md           #     → gui/（79 篇，hm_ GUI 命令）
│   │   └── core_data.md     #     → core_data/（242 篇 Data Names）
│   ├── modify/              #   修改命令页（文件名 `*foo` → `_foo.md`）
│   ├── query/               #   查询命令页
│   ├── gui/                 #   GUI 命令页
│   └── core_data/           #   Data Names 页（data_names-<类型>.md）
└── hv_help/                 # HyperView Tcl API（61 类 · 2033 命令）
    ├── README.md            #   总索引
    ├── _index/
    │   ├── by_function.md   #     按功能域（16 域）→ 类 → 命令
    │   ├── by_class.md      #     按类（61 类 × 命令表）
    │   └── all_commands.md  #     全部命令字母序速查
    ├── chapter_heads/       #   官方类总览页（<class>_class_r.md）
    ├── reference/tcl/       #   命令页（<class>_<method>.md，2033 + 专题）
    └── reference/hwdref/    #   报告框架（RPTI / ARDI / Python，独立体系）
```

索引均为表格，常用列：`| Command | File | Description |` 或 `| 命令 | 类 | 文件 |`。拿到 **File 列相对路径** 后，用 `read_file` 打开对应命令页（相对 workspace 根目录）。

## 流程 A — 查询 HyperMesh 命令

**Step 1 — 判断需要查询的命令类别（修改命令 / 查询命令 / GUI 命令）：**

| 类别 | 目录 | 文件数 | 定位 |
| --- | --- | --- | --- |
| 修改命令 | `modify/` | 1991 | 修改 HyperMesh 软件内的有限元模型数据（几何 / 网格 / 连接器 / 材料…） |
| 查询命令 | `query/` | 641 | 查询 HyperMesh 软件内的有限元模型数据（取值 / 判型 / 几何计算…） |
| GUI 命令 | `gui/` | 79 | 操作 HyperMesh 界面组件（视图 / 高亮 / 绘制 / 对话框…） |

**Step 2 — 在索引表中定位：** 用命令名精确匹配表格首列。复制 `File` 列的相对路径。注意修改命令的文件名 `*` → `_`（如 `*createmark` → `modify/_createmark.md`）。

**Step 3 — 读取命令页并提取：** 命令页格式统一：

```text
# 命令名              → 全文唯一标识
> 一句话简介
## Syntax             → tcl 调用签名（直接可用）
**Type:**             命令类别
## Description        → 详细说明（含默认行为、坑）
## Inputs             → 参数逐项说明
## Example            → tcl 示例代码
## Errors             → catch 容错标准写法
## See Also           → 相关命令
```

## 流程 B — 查询 HyperMesh Data Names（core_data）

**Step 1 — 确认实体类型：** 如 `nodes`、`elements-quad4`、`surfaces`、`components`、`materials`、`properties`、`connectors`、`contactsurfs`、`designvars_*`、`loadcols`…（页面名即实体类型，见 `core_data/data_names-*.md`）。

**Step 2 — 在 `_index/core_data.md` 中定位**该实体类型的数据名页链接。

**Step 3 — 读取数据名页：** 页面是**扁平定义序列**：`数据名` + 一句话说明 + `Type: <类型>`（如 `id` → `Type: unsigned integer`、`coordinates` → `Type: triple double`、`node1` → `Type: entity`）。返回数据名、说明与类型；注意指针引用语法：`node1.id`（点号连接指针与目标数据名）。

## 流程 C — 查询 HyperView 命令（类 + 方法）

三种入口任选其一：

| 场景 | 入口 |
| --- | --- |
| 想实现某类功能（画云图 / 加载结果 / 加注释 / 截面 / 热点…） | `_index/by_function.md`（16 功能域 → 类 → 命令，含手写类说明） |
| 已知类名（如 `poIContourCtrl`） | `_index/by_class.md`（命令表）+ `chapter_heads/<class>_class_r.md`（官方类总览，列出全部方法） |
| 记得命令名但不确定属于哪个类 | `_index/all_commands.md`（2033 命令字母序，`\|命令\|类\|文件\|`） |

定位后打开 `reference/tcl/<class>_<method>.md`。命令页 H1 = `类名 方法名`（如 `poIModel GetLabel`），调用形式为 `类名_handle 方法名 参数...`；段落：`Syntax` / `Application`（HyperView Tcl Query / Modify / Command）/ `Description` / `Errors`。

> `reference/hwdref/` 是独立的报告 / PPT 发布框架（RPTI / ARDI / Python），不并入命令索引，单独查询。

## 已知坑 / 注意事项

- **命令显示名以命令页 H1 为准**，部分文件名有官方笔误，但索引链接仍指向真实文件：`poirscalardefine_*`、`poisubxase_*`、`poivectorcrl_*`、`poitrackinsystem_*`、`poirenderctrl_appendsimulation`（实为 `poIResultCtrl` 系等）
- `poibestview_*` 的命令页 H1 无类前缀，靠文件名前缀回退归类
- `poicomponent_getlist` 的命令页 H1 是 `poIComponent GetLabel`（官方数据怪癖）
- `_2` 后缀 = 同名重载版本（索引中标记〔2〕），如 `hwisession_capturewindow_2.md`
- `_r` 后缀 = 已移除 / 废弃，保留仅供查阅旧版（如 `data_names-elements-hex8_r.md`）
- HyperMesh 命令修订后缀：`_2`、`_11`、`_12`、`_temp`、`_new` 等
- 废弃 / 未收录：`deprecated_tcl_*_commands.md`（旧 → 新命令迁移表，位于 `gui/`、`query/` 等）、`undocumented_tcl_*_commands.md`（官方无文档的命令清单）
- HyperView 类归属算法：H1 与类名**最长前缀匹配**；匹配不到再用文件名前缀（去 `_class_r` 后缀）
- HyperMesh 命令前缀族：`_ce_*` / `_CE_*`（连接器）、`_morph*`（网格变形）、`_hf_*`（钣金成型）、`_me_*`（模块）、`_solidmap_*`、`_xyplot*`、`_voxel_lattice_hex_mesh_*`、`_midsurface_*`（中面）等
