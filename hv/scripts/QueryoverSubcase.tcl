namespace eval ::HvToolkit::QueryoverSubcase {

    namespace export *

    # 入口：弹出非模态输入对话框。
    # 用户在 entry 输入字符串，点"确定"后打印输入值到控制台并关闭窗口。
    proc GUI {} {
        # 若对话框已存在，先删除其所有子窗口再删除主窗口，随后重建
        if {[winfo exists .qos_diag]} {
            foreach child [winfo children .qos_diag] {
                destroy $child
            }
            destroy .qos_diag
        }

        # 主窗口
        hwtk::toplevel .qos_diag
        wm title    .qos_diag "QueryoverSubcase"
        wm resizable .qos_diag 0 0
        wm protocol  .qos_diag WM_DELETE_WINDOW {destroy .qos_diag}

        # 控件
        hwtk::label  .qos_diag.lbl -text "Selection Set Ids: " -anchor w
        hwtk::entry  .qos_diag.ent -width 20 -validate key \
            -validatecommand {::HvToolkit::QueryoverSubcase::_valid_new_value %P}
        hwtk::label  .qos_diag.thr_lbl -text "Allowable Stress: " -anchor w
        hwtk::entry  .qos_diag.thr -width 20 -validate key \
            -validatecommand {::HvToolkit::QueryoverSubcase::_valid_threshold %P}
        hwtk::button .qos_diag.ok  -text "Query over Subcase" \
            -command {::HvToolkit::QueryoverSubcase::perform}

        # 布局
        grid .qos_diag.lbl     -row 0 -column 0 -padx 10 -pady 8 -sticky w
        grid .qos_diag.ent     -row 0 -column 1 -padx 10 -pady 8 -sticky ew
        grid .qos_diag.thr_lbl -row 1 -column 0 -padx 10 -pady 8 -sticky w
        grid .qos_diag.thr     -row 1 -column 1 -padx 10 -pady 8 -sticky ew
        grid .qos_diag.ok      -row 2 -column 0 -columnspan 2 -pady 8
        grid columnconfigure .qos_diag 1 -weight 1

        # 居中显示（显式设置窗口尺寸，避免 HyperView 不按请求尺寸铺开导致顶部被裁）
        update idletasks
        set w [winfo reqwidth  .qos_diag]
        set h [winfo reqheight .qos_diag]
        set x [expr {([winfo screenwidth  .qos_diag] - $w) / 2}]
        set y [expr {([winfo screenheight .qos_diag] - $h) / 3}]
        wm geometry .qos_diag ${w}x${h}+$x+$y

        # 回车触发确定；聚焦输入框
        bind .qos_diag.ent <Return> {.qos_diag.ok invoke}
        focus -force .qos_diag.ent
    }

    # 校验：validatecommand 收到的是每次输入后的完整新值（%P），因此整体校验。
    # 新值须为"空格分隔的正整数列表"（如 "1 2 8 72"）：允许空值/纯空格；
    # 数字不允许前导 0，且不得为 0/负数/小数/字母/符号。
    proc _valid_new_value {value} {
        return [regexp {^\s*([1-9][0-9]*(\s+[1-9][0-9]*)*)?\s*$} $value]
    }

    # 校验许用强度：允许空值（不进行着色），或正整数（同 Selection Set Ids）
    proc _valid_threshold {value} {
        return [regexp {^\s*([1-9][0-9]*)?\s*$} $value]
    }

    # CSV 字段转义：含逗号/引号/换行时用引号包裹，内部引号双写
    proc _csv_escape {s} {
        if {[regexp {[",\r\n]} $s]} {
            return "\"[string map {" ""} $s]\""
        }
        return $s
    }

    # ---- 进度条 ----
    # HyperView 内嵌 Tcl 没有官方的 statuswindow 命令（那是 HyperMesh 的）。
    # 用内置 ::progressbar 控件（行为与 ttk::progressbar 一致）：determinate + maximum/value。
    proc _progress_open {total} {
        if {[winfo exists .qos_prog]} {destroy .qos_prog}
        hwtk::toplevel .qos_prog
        wm title .qos_prog "Query over Subcase"
        wm resizable .qos_prog 0 0
        wm protocol .qos_prog WM_DELETE_WINDOW {}   ;# 处理中禁止手动关闭

        hwtk::label .qos_prog.lbl -text "Preparing..." -anchor w
        hwtk::progressbar .qos_prog.bar -mode determinate -length 450 -maximum $total -value 0
        hwtk::label .qos_prog.pct -text "0%" -anchor e

        grid .qos_prog.lbl -row 0 -column 0 -columnspan 2 -sticky ew -padx 12 -pady 10
        grid .qos_prog.bar -row 1 -column 0 -columnspan 2 -sticky ew -padx 12 -pady 14
        grid .qos_prog.pct -row 2 -column 1 -sticky e -padx 12 -pady 8

        # 居中显示（同 GUI 的做法）
        set w [winfo reqwidth  .qos_prog]
        set h [winfo reqheight .qos_prog]
        set x [expr {([winfo screenwidth  .qos_prog] - $w) / 2}]
        set y [expr {([winfo screenheight .qos_prog] - $h) / 3}]
        wm geometry .qos_prog +$x+$y
        wm deiconify .qos_prog

        update idletasks
    }

    # 更新进度：done/total（0..total），text 为状态文字；用 update idletasks 强制重绘。
    # 用 update idletasks 而非 update：只重绘、不处理用户输入事件，天然防重入。
    proc _progress_set {done total text} {
        if {![winfo exists .qos_prog]} {return}
        set pct [expr {$total > 0 ? int(100.0 * $done / $total) : 0}]
        .qos_prog.bar configure -value $done
        .qos_prog.pct configure -text "$pct%"
        if {$text ne ""} {.qos_prog.lbl configure -text $text}
        update idletasks
    }

    # 关闭进度窗口
    proc _progress_close {} {
        if {[winfo exists .qos_prog]} {destroy .qos_prog}
    }

    # "确定"回调：校验输入为"空格分隔的正整数列表"，合法后继续处理。
    # 遍历所选 selection set 的各个 subcase，统计每个 subcase 的最大应力，
    # 导出 CSV 到模型目录，并调用 write_excel（打包 exe 或本机 python）生成带高亮的 xlsx。
    proc perform {} {
        set selection_sets [string trim [.qos_diag.ent get]]
        if {[llength $selection_sets] eq 0} {return -code error "Invalid Selection Set Ids"}
        HvToolkit::Support lunique selection_set

        # 许用强度：可选，留空则不进行着色；非空按 MaxValue/许用强度 比值着色
        # （<0.8 不着色 / 0.8~1 黄 / >1 红）
        set threshold [string trim [.qos_diag.thr get]]

        # 输出目录：优先模型文件所在目录；模型未保存（无文件名）时回退当前工作目录
        set model_file [HvToolkit::HvApi::get_model_filename]
        set out_dir [file dirname $model_file]
        set base    [file rootname [file tail $model_file]]
        set csv [file join $out_dir "${base}_query.csv"]

        set fp [open $csv w]
        fconfigure $fp -encoding utf-8
        # BOM：保证中文 Windows 下 Excel 直接打开 CSV 不乱码
        puts $fp "\uFEFFSelectionSet,Subcase,MaxValue,EntityID,TimeStep"

        set set_num [llength $selection_sets]
        set sc_num [llength [HvToolkit::HvApi::get_subcase_list]]
        set total [expr $set_num * $sc_num]
        _progress_open $total
        set done 0
        if {[catch {
            foreach set $selection_sets {
                set set_label [dict get [HvToolkit::HvApi::info_selectionset $set] label]
                set stress_data [HvToolkit::HvApi::get_contour_value $set "Element Stresses (2D & 3D)"]
                set done_sc 0
                foreach {sc sc_data} $stress_data {
                    _progress_set $done $total "Processing ([expr $done * $sc_num + $done_sc]/$total): Selection Set $set"
                    set sc_label [HvToolkit::HvApi::get_subcase_label $sc]
                    set max_value 0
                    set max_si_id  0
                    set max_entity_id 0
                    # 遍历 subcase 下所有 simulation 的节点/单元，找到最大值并记录
                    foreach {si si_data} $sc_data {
                        foreach {entity entity_data} $si_data {
                            if {$entity_data > $max_value} {
                                set max_value  $entity_data
                                set max_si_id  $si
                                set max_entity_id $entity
                            }
                        }
                    }
                    set si_label [HvToolkit::HvApi::get_simulation_label $sc $max_si_id]
                    # max_value 可能是科学计数法（如 1.23e+05），输出时四舍五入为整数
                    incr done_sc
                    puts $fp "[_csv_escape $set_label],[_csv_escape $sc_label],[expr {round($max_value)}],$max_entity_id,[_csv_escape $si_label]"
                }
                incr done
            }
        } err]} {
            # 出错清理：关进度窗口、关文件、删除半成品 CSV
            _progress_close
            close $fp
            # file delete -force $csv
            return -code error $err
        }
        _progress_close
        close $fp

        # 调用转换器生成带高亮的 xlsx：优先插件自带的 exe，其次本机 python
        set script [file join $HvToolkit::scripts_dir "write_excel.py"]
        set exe [file join $HvToolkit::scripts_dir "bin" "write_excel.exe"]
        set xlsx [file join $out_dir "${base}_query.xlsx"]

        set converter [list [file nativename $exe]]
        set converter [list python [file nativename $script]]

        set args [list [file nativename $csv] [file nativename $xlsx]]
        if {$threshold ne ""} {lappend args $threshold}
        if {[catch {exec {*}$converter {*}$args} out]} {
            tk_messageBox -icon error -message "Fail to convert xlsx\n$out"
            return
        }

        tk_messageBox -icon info -message "Query successfully and excel save at:\n$xlsx"
    }
}