# HvToolkit 通用工具库（纯 Tcl，与 HyperView 客户端无关，参考 hm/hm_lib/Support.tcl）
namespace eval HvToolkit::Support {

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
            return [expr [lindex $v1 0] * [lindex $v2 0] + [lindex $v1 1] * [lindex $v2 1] + [lindex $v1 2] * [lindex $v2 2]]
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

        proc m {vec} {
            return [expr sqrt([dot $vec $vec])]
        }

        proc normalize {vec} {
            set len [m $vec]
            if {$len == 0} { return $vec }
            return [mul $vec [expr {1.0 / $len}]]
        }

        namespace ensemble create
    }

    # 生成整数序列。range 5 -> 0 1 2 3 4；range 2 6 -> 2 3 4 5
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

    # 列表去重（保持首次出现顺序）
    proc lunique {list} {
        set res {}
        foreach e $list {
            if {$e ni $res} { lappend res $e }
        }
        return $res
    }

    # 从列表中移除指定元素（全部匹配）
    proc lremove {list args} {
        foreach e $args {
            set list [lsearch -all -inline -not -exact $list $e]
        }
        return $list
    }

    namespace ensemble create
}
