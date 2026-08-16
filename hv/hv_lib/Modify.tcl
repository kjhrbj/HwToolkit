# HvToolkit HyperView 修改库：封装 hwi 修改类 API（参考官方 demo：hwdesktop/demos/sdk/extensions/Extension_Demo/hv/hv-init.tcl）
namespace eval HvToolkit::Modify {

    namespace export *

    # 将激活 HyperView 窗口截图保存为 PNG 到当前工作目录。
    # 参考官方 demo 的 CaptureHVWindowToJPEGFileFixedNamResolution。
    # 返回保存的完整路径；失败返回空串。
    proc capture_active_window {args} {
        set width  1920
        set height 1080
        if {[llength $args] >= 2} {
            lassign $args width height
        }
        set t [expr rand()][clock milliseconds]
        hwi GetSessionHandle sesh$t
        if {[catch {sesh$t GetSystemVariable CURRENTWORKINGDIR} exportDir]} {
            sesh$t ReleaseHandle
            return ""
        }
        set filePath [file join $exportDir "capture_${t}.png"]
        if {[catch {sesh$t CaptureActiveWindow PNG "$filePath" pixels $width $height} err]} {
            sesh$t ReleaseHandle
            return ""
        }
        sesh$t ReleaseHandle
        return $filePath
    }

    # 将激活 HyperView 窗口截图复制到剪贴板。
    # 返回 1 成功 / 0 失败。
    proc capture_active_window_clipboard {} {
        set t [expr rand()][clock milliseconds]
        hwi GetSessionHandle sesh$t
        if {[catch {sesh$t CaptureScreen CLIPBOARD dummyFileName.png} err]} {
            sesh$t ReleaseHandle
            return 0
        }
        sesh$t ReleaseHandle
        return 1
    }

    namespace ensemble create
}
