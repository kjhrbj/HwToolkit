# HwToolkit

HyperWorks 二次开发工具包，用于加速 HyperMesh 前处理建模与 HyperView 后处理。基于 Tcl/Tk 开发，以扩展（Extension）方式集成到 HyperWorks Desktop。

- **适用版本**：Altair HyperWorks 2023 及以上
- **当前版本**：0.1
- **作者**：Xiemc

## 功能概览

| 模块 | 命名空间 | 说明 |
| --- | --- | --- |
| HyperMesh 工具 | `::HmToolkit::Modify` / `::HmToolkit::Query` / `::HmToolkit::Support` | 建模相关操作：创建 LoadStep / 载荷 / 材料 / 属性 / RBE 等 |
| HyperView 工具 | `::HvToolkit::Modify` / `::HvToolkit::Query` / `::HvToolkit::Support` | 后处理相关操作：窗口捕获、结果查询等 |
| 工具栏 | `::HmToolkit::Toolbar` / `::HvToolkit::Toolbar` | Ribbon / 工具栏快捷命令（如另存带时间戳副本、相似面选择等） |
| 上下文面板 | `hm/contexts/*.xml` + `*.tcl` | 右键上下文菜单命令（AutoSeam、CreateRbe2、ThicknessAssign 等） |

## 目录结构

```
HwToolkit/
├── extension.xml            # HyperWorks 扩展清单（入口定义）
├── init.tcl                 # 扩展入口脚本（声明 HmToolkit / HvToolkit 命名空间）
├── hm/                      # HyperMesh profile
│   ├── hm_init.tcl          #   HM 入口，自动加载 lib / toolbar
│   ├── hm_ribbon.xml        #   Ribbon 定义
│   ├── hm_lib/              #   核心库（Modify / Query / Support）
│   ├── contexts/            #   上下文面板（命令 + XML 定义）
│   ├── toolbar/             #   工具栏脚本 + XML
│   └── images/              #   图标资源
├── hv/                      # HyperView profile（结构同 hm/）
├── HelpDocforAi/            # 官方 API 文档 Markdown 提取版（仅本地 AI 辅助检索用，不入库）
│   ├── hm_help/             #   HyperMesh Tcl 命令 / Data Names 文档
│   └── hv_help/             #   HyperView Tcl / hwdref 报告框架文档
├── TestMode/                # 本地测试模型（不入库）
└── .venv/                   # Python 虚拟环境（仅本地，不入库）
```

## 安装 / 使用

1. 在 HyperWorks Desktop 中通过 `extension.xml` 加载本扩展（HyperWorks 2023+）。
2. 启动后对应 profile 会自动 `source` `hm/hm_init.tcl` 或 `hv/hv_init.tcl`，加载核心库与工具栏。
3. 在 Tcl 命令行直接调用命名空间内命令，例如：

```tcl
# HyperMesh：创建一个静态 LoadStep
::HmToolkit::Modify::Create::loadstep "MyStep" Static

# HyperMesh：创建材料
::HmToolkit::Modify::Create::material "Steel" 210000 0.3

# HyperView：获取当前激活模型 ID
::HvToolkit::Query::active_model_id
```

## 开发辅助

- 本地目录 `HelpDocforAi/` 收录了 Altair 官方帮助的 Markdown 提取版（约 5100 篇，**不纳入版本管理、不随仓库推送**），配合 `.github/skills/hw-api-doc-query` 技能可按命令名快速检索 API 用法。
- 官方帮助文档提取版仅供本地/内部开发参考，请勿公开发布。

## 备注

- `TestMode/`、`.venv/` 与 `HelpDocforAi/` 均为本地产物，已通过 `.gitignore` 排除，不纳入版本管理。
