namespace eval HmToolkit::Support {

    namespace export *

    namespace eval Vector {
        namespace export *

        proc cross {v1 v2} {
            set x [expr [lindex $v1 1]*[lindex $v2 2] - [lindex $v1 2]*[lindex $v2 1]]
            set y [expr [lindex $v1 2]*[lindex $v2 0] - [lindex $v1 0]*[lindex $v2 2]]
            set z [expr [lindex $v1 0]*[lindex $v2 1] - [lindex $v1 1]*[lindex $v2 0]]
            return "$x $y $z"
        }

        proc dot {v1 v2} {
            return [expr [lindex $v1 0] * [lindex $v2 0] + [lindex $v1 1] * [lindex $v2 1] + [lindex $v1 2] * [lindex $v2 2] ] 
        }

        proc mul {v n} {
            return "[expr [lindex $v 0] * $n] [expr [lindex $v 1] * $n] [expr [lindex $v 2] * $n]"
        }

        proc add {args} {
            set x 0
            set y 0
            set z 0
            foreach vec $args {
                set x [expr $x + [lindex $vec 0]]
                set y [expr $y + [lindex $vec 1]]
                set z [expr $z + [lindex $vec 2]]
            }
            return "$x $y $z"
        }

        proc sub {v1 v2} {
            set x [expr [lindex $v1 0] - [lindex $v2 0]]
            set y [expr [lindex $v1 1] - [lindex $v2 1]]
            set z [expr [lindex $v1 2] - [lindex $v2 2]]
            return "$x $y $z"
        }

        proc normalize {vec} {
            set m [dot $vec $vec]
            set m [expr 1 / ($m ** 0.5)]
            return [mul $vec $m]
        }

        proc m {vec} {
            return [expr [dot $vec $vec] ** 0.5]
        }

        namespace ensemble create
    }

    namespace eval History {
        namespace export *

        # 开始一个可撤销的历史分组。参考 HyperMesh context 框架 (scriptablebase.tcl)：
        # 必须同时打开 hm_private_frwk enablehistoryfromtcl 1，否则即使命令本身
        # 支持历史(hm_ishistorysupported=1)，从 TCL 执行的命令也不会写入 undo 历史。
        proc start {name} {
            hm_private_frwk enablehistoryfromtcl 1
            *startnotehistorystate $name
        }

        # 结束历史分组，并关闭 TCL 历史记录开关。
        proc end {name} {
            *endnotehistorystate $name
            hm_private_frwk enablehistoryfromtcl 0
        }

        namespace ensemble create
    }

    proc range {start {end None} {step 1}} {

        if {![string is integer -strict $end]} {
            set end $start
            set start 0
        }

        set res {}
        for {set i $start} {$i < $end} {incr i $step} {
            lappend res $i
        }

        return $res
    }

    # 返回当前数据库中某实体类型的“最近创建”的 num 个 ID，一般用于定位刚创建的实体。
    # 参数:
    #   type - HyperMesh 实体类型名，如 "nodes" "elems" "lines" "surfs" "comps"
    #   num  - 需要的 ID 数量（默认 1）
    # 返回:
    #   最近 num 个 ID 的列表；若 num < 1 返回 {}。
    # 实现说明:
    #   1) num <= 100：用 *createmark 的负 ID 范围（-num..0）取“数据库中末尾 num 个”
    #      实体，再 hm_getmark 取 ID。速度快。
    #   2) num > 100：用 hm_entitymaxid 取当前最大 ID，向前推 num 个组成区间，
    #      避免超大 mark 的性能问题。
    # ⚠️ 注意:
    #   - 假设“新建实体拥有最大的 ID”。但 HyperMesh 会通过 ID 池(id pool)复用
    #     被删除实体的 ID，此时新建实体可能拿到比旧 max 小的 ID，本函数会漏掉/取错。
    #     对正确性要求高的场景请改用 get_creation（列表求差）。
    #   - “末尾 num 个”按 ID 排序，不保证顺序与创建顺序一致。
    proc currentids {type {num 1}} {
        if {$num < 1} {
            return {}
        } elseif {$num <= 100} {
            *createmark $type 1 {*}[range -$num 0]
            return [hm_getmark $type 1]
        } else {
            set maxid [hm_entitymaxid $type]
            incr maxid
            set minid [expr $maxid - $num]
            return [range $minid $maxid]
        }
    }

    proc entitiesnum {type} {
        return [llength [hm_entitylist $type id]]
    }

    # 执行一段可能创建实体的脚本 body，并返回其中新建的该类型实体 ID。
    # 参数:
    #   type - HyperMesh 实体类型名
    #   body - 待执行的 Tcl 脚本；在调用者的上下文中求值（见 uplevel）
    # 返回:
    #   新建实体的 ID 列表；若 body 抛出异常或没有新建实体，返回 {}。
    # 实现说明:
    #   - 通过 hm_entitylist 在 body 前后各取一次全部 ID，求差集得到新实体。
    #   - 这是确定新建实体 ID 最稳妥的方式：不受 ID 池复用影响。
    #   - body 用 uplevel 执行，可访问调用者的局部变量；错误会向上抛出。
    # 注意:
    #   - 性能：需两次全量 hm_entitylist，大模型上较慢；高频路径可考虑
    #     官方的 hm_entityrecorder 等追踪 API。
    # [备用兜底] 列表求差法获取新建实体 ID（已被 get_creation_rec 取代，保留作无依赖兜底）。
    proc get_creation {type body} {
        set previous_ids [hm_entitylist $type id]
        if {[catch {uplevel $body}]} {
            return {}
        }
        set current_ids [hm_entitylist $type id]
        set l1 [llength $previous_ids]
        set l2 [llength $current_ids]
        set n [expr $l2  - $l1]
        if {$n > 0} {return [HmToolkit::Support currentids $type $n]} else {return {}}
    }

    # 基于 hm_entityrecorder 的 get_creation 高性能版本，接口与 get_creation 一致。
    # 参数:
    #   type - HyperMesh 实体类型名；也可传 0 记录所有类型
    #   body - 待执行的 Tcl 脚本；在调用者的上下文中求值（见 uplevel）
    # 返回:
    #   新建实体的 ID 列表；若 body 抛出异常返回 {}。
    # 实现说明:
    #   - 用官方 hm_entityrecorder 原生记录实体创建，避免 get_creation 的
    #     两次全量 hm_entitylist + 解释层求差，大模型/高频下更快，且不受 ID 池复用影响。
    #   - 流程：on → 执行 body → off → ids（官方示例即在 off 后再取 ids）。
    #   - 用 catch 保证 body 出错时也会执行 off，避免 recorder 残留占用。
    # 注意:
    #   - recorder 是全局有状态开关：记录"开启期间该类型的所有新建实体"，
    #     若 body 中途失败且未关闭，后续调用会混入无关 ID，故必须保证成对开关。
    #   - 不可重入：body 内部不要再调用 hm_entityrecorder，否则行为未定义。
    #   - 与 get_creation 相同，body 的错误会被吞掉并返回 {}（可自行用返回值处理）。
    proc get_creation_rec {type body} {
        hm_entityrecorder $type on
        set code [catch {uplevel $body} result]
        hm_entityrecorder $type off
        if {$code} {
            return {}
        }
        return [hm_entityrecorder $type ids]
    }

    proc remove_noexist {type list_name} {
        upvar $list_name ids
        set res {}
        foreach id $ids {
            if {[HmToolkit::Query exist $type id=$id]} {lappend res $id}
        }
        set ids $res
    }

    proc lremove {list_name values} {
        set res {}
        upvar $list_name list
        foreach item $list {
            if {$item in $values} {continue} else {lappend res $item}
        }
        set list $res
    }

    # [未调用] 列表元素替换。当前无调用，保留备用。
    proc lreplace {list_name value new_value} {
        set res {}
        upvar $list_name list
        foreach item $list {
            if {$item ne $value} {lappend res $item} else {lappend res $new_value}
        }
        set list $res
    }

    proc lunique {list_name} {
        set res {}
        upvar $list_name list
        foreach item $list {
            if {!($item in $res)} {lappend res $item}
        }
        set list $res
    }

    # [未调用] 由 keys/values 构建字典。当前无调用，保留备用。
    proc dict_create {keys values} {
        set res {}
        set index 0
        while {$index<[llength $keys]} {
            dict append res [lindex $keys $index] [lindex $values $index]
            incr index
        }
        return $res
    }

    namespace ensemble create

}

