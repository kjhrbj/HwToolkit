if {[itcl::is class ::HmToolkit::HoleRbe2Ctx]} { itcl::delete class ::HmToolkit::HoleRbe2Ctx}

itcl::class ::HmToolkit::HoleRbe2Ctx {
    inherit ::hm::context::HMScriptableBase
    constructor {args} {}

    public method proceed {args}
    public method ok {args}
    public method cancel {args}

    public method OnPost {args}
    public method OnUnpost {args}
    public method OnSelectionChange {args}
    public method AutoProceed {args}

    private method __perform {args}
}

itcl::body ::HmToolkit::HoleRbe2Ctx::proceed {args} {
    if {![ctx::selection count ElemsSelector]} {return 0}
    ctx StartRecordHistory "Auto Rbe2"
    if {[catch {__perform} error_info]} {
        ctx EndRecordHistory "Auto Rbe2"
        ctx Undo
        ctx::selection clear ElemsSelector
        ctx SetActiveSelection ElemsSelector
        Message "Function failed for unknown reason!\nerror info:$error_info"
        return 0
    } else {
        ctx EndRecordHistory "Auto Rbe2"
        ctx::selection clear ElemsSelector
        ctx SetActiveSelection ElemsSelector
        return 1
    }
}

itcl::body ::HmToolkit::HoleRbe2Ctx::ok {args} {
    if {[proceed]} {ctx::manager exit}
}

itcl::body ::HmToolkit::HoleRbe2Ctx::cancel {args} {
    ctx::manager exit
}

itcl::body ::HmToolkit::HoleRbe2Ctx::OnPost {args} {

}

itcl::body ::HmToolkit::HoleRbe2Ctx::OnUnpost {args} {

}

itcl::body ::HmToolkit::HoleRbe2Ctx::OnSelectionChange {args} {

}

itcl::body ::HmToolkit::HoleRbe2Ctx::AutoProceed {args} {
    hwctx proceed
}

itcl::body ::HmToolkit::HoleRbe2Ctx::__perform {args} {
    set elems [ctx::selection ids ElemsSelector]
    set comp_name [ctx GetOption name]
    set tube [ctx GetOption tube]
    set connect [ctx GetOption connect]
    set type [ctx GetOption type]

    set tolerance [ctx GetOption tolerance]

    set max_d [ctx GetOption max_d]
    set min_d [ctx GetOption min_d]
    set max_r [expr $max_d / 2.0]
    set min_r [expr $min_d / 2.0]

    if {![set comp [HmToolkit::Query exist comps name=$comp_name]]} {set comp [HmToolkit::Modify Create comps $comp_name]}
    *currentcollector comp $comp_name

    set hole_infos [HmToolkit::Query detect_hole elems $elems $tube]

    set hole_nodes {}

    set n [llength $hole_infos]
    set index 0
    set flag {}

    # 遍历holes，根据hole之间的距离和axis的夹角判断，将应该rbe2抓在一起的nodes放在一起
    for {set i 0} {$i < $n} {incr i} {
        if {$i in $flag} {continue}
        set hi [lindex $hole_infos $i]
        if {[lindex $hi 1] > $max_r} {continue}
        if {[lindex $hi 1] < $min_r} {continue}
        for {set j [expr $i + 1]} {$j < $n} {incr j} {
            if {$j in $flag} {continue}
            set hj [lindex $hole_infos $j]

            if {[lindex $hj 1] > $max_r} {continue}
            if {[lindex $hj 1] < $min_r} {continue}

            set center1 [lindex $hi 2]
            set center2 [lindex $hj 2]

            set dist [HmToolkit::Query get_dist $center1 $center2]
            if {$dist > $tolerance} {continue}

            set cos [HmToolkit::Query get_cos_vec [lindex $hi 3] [lindex $hj 3]]
            if {$cos < 0.966 && $cos > -0.966} {continue}

            set center_vector [HmToolkit::Support Vector normalize [HmToolkit::Support Vector sub $center1 $center2]]
            set cos [HmToolkit::Query get_cos_vec [lindex $hi 3] $center_vector]
            if {$cos < -1 || $cos > 1} {set cos 1}
            set sin [expr (1 - $cos**2)**0.5]
            set deviation [expr $sin * $dist]
            if {$deviation > [lindex $hj 1]} {continue}
            if {$deviation > [lindex $hi 1]} {continue}

            if {[llength [lindex $hj 4]] > 1} {
                dict lappend hole_nodes $index [lrange [lindex $hj 4] 1 end]
            }
            lappend flag $j
        }

        if {$connect && ![dict exists $hole_nodes $index]} {
            incr index
            continue
        }
        if {[llength [lindex $hi 4]] > 1} {
            dict lappend hole_nodes $index [lrange [lindex $hi 4] 1 end]
        }

        incr index
    }

    set bolt_rod_nodes_dict {}
    foreach {index hole_nodes_list} $hole_nodes {
        set rbe_nodes {}
        foreach hole_nodes $hole_nodes_list {
            set new_rbe [HmToolkit::Modify Create Rbe2 $hole_nodes]
            lappend rbe_nodes [hm_getvalue elems id=$new_rbe dataname=independentnode]
        }

        if {[llength $rbe_nodes] > 1} {
            dict lappend bolt_rod_nodes_dict $index {*}$rbe_nodes
        }
    }
    puts "bolt_rod_nodes_dict: $bolt_rod_nodes_dict"
    switch $type {
        "Rbe2-Rbe2" {
            foreach {index rbe_nodes} $bolt_rod_nodes_dict {
                HmToolkit::Modify Create Rbe2 $rbe_nodes
            }
        }
        "Rbe2-Spring" {
            set comp_spring $comp_name-Spring
            if {![set comp [HmToolkit::Query exist comps name=$comp_spring]]} {set comp [HmToolkit::Modify Create comps $comp_spring]}
            *currentcollector comp $comp_spring

            set spring_prop [HmToolkit::Modify Create bush_property $comp_spring "-1 -1 -1 -1 -1 -1"]
            *setvalue comps id=$comp propertyid=$spring_prop

            foreach {index rbe_nodes} $bolt_rod_nodes_dict {
                for {set i 0} {$i < [llength $rbe_nodes] - 1} {incr i} {
                    set n1 [lindex $rbe_nodes $i]
                    set n2 [lindex $rbe_nodes [expr {$i + 1}]]

                    HmToolkit::Modify Create spring $n1 $n2
                }
            }
        }
        default {error "Unknown type: $type"}
    }

    *clearmark elems 1
    *clearmark elems 2
    return 1
}

ctx::manager register hm HoleRbe2Ctx "::HmToolkit::HoleRbe2Ctx"
puts "register: HmToolkit::HoleRbe2Ctx"