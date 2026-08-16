# hv/images

本目录为 HyperView 扩展预留的图标目录（与 `hm/images` 平行）。

**注意**：`extension.xml` 的 `<entry name="resources" value="hm/images" />` 是**全局**条目，
当前 HyperView 的 ribbon/toolbar 图标从 `hm/images/` 解析，因此 `hv_ribbon.xml` / `toolbars/toolbar.xml`
暂时复用了其中的图标（`CreateStep-80.png` / `SaveFile-32.png` / `Similar-32.png`）。

若希望 HyperView 使用独立图标，可选：
- 把图标放入本目录，并把 `resources` 改为共享根目录 `images/`（将 `hm/images` 内容上移），参考官方 demo（`Extension_Demo`）的共享 `images/` 做法；
- 或维持现状，继续复用 `hm/images` 的图标。
