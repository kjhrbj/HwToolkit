if {[itcl::is class ::HmToolkit::CreateJointCtx]} { itcl::delete class ::HmToolkit::CreateJointCtx}

itcl::class ::HmToolkit::CreateJointCtx {
    inherit ::hm::context::HMScriptableBase
    constructor {args} {}

    public method proceed {args}
    public method ok {args}
    public method cancel {args}

    public method OnPost {args}
    public method OnUnpost {args}
    public method OnSelectionChange {args}
    public method AutoProceed {args}

    public method change_type {args}

    private method __perform {args}

}

itcl::body ::HmToolkit::CreateJointCtx::proceed {args} {
    if {![ctx::selection count NodesSelector1] || ![ctx::selection count NodesSelector2]} {return 0}
    ctx StartRecordHistory "Create Joint"
    if {[catch {__perform} error_info]} {
        ctx EndRecordHistory "Create Joint"
        ctx Undo
        ctx::selection clear NodesSelector1
        ctx::selection clear NodesSelector2
        ctx SetActiveSelection NodesSelector2
        Message "Function failed for unknown reason!\nerror info:$error_info"
        return 0
    } else {
        ctx EndRecordHistory "Create Joint"
        ctx::selection clear NodesSelector1
        ctx::selection clear NodesSelector2
        ctx SetActiveSelection NodesSelector2
        return 1
    }
}

itcl::body ::HmToolkit::CreateJointCtx::ok {args} {
    if {[proceed]} {ctx::manager exit}
}

itcl::body ::HmToolkit::CreateJointCtx::cancel {args} {
    ctx::manager exit
}

itcl::body ::HmToolkit::CreateJointCtx::OnPost {args} {

}

itcl::body ::HmToolkit::CreateJointCtx::OnUnpost {args} {

}

itcl::body ::HmToolkit::CreateJointCtx::OnSelectionChange {args} {

}

itcl::body ::HmToolkit::CreateJointCtx::AutoProceed {args} {
    proceed
}

itcl::body ::HmToolkit::CreateJointCtx::change_type {args} {
    set type [ctx GetOption type]
    if {$type eq "Rbe2-Beam"} {
        ctx::ui set radius -visible 1
    } else {
        ctx::ui set radius -visible 0
    }
}

itcl::body ::HmToolkit::CreateJointCtx::__perform {args} {
    set nodes1 [ctx::selection ids NodesSelector1]
    set nodes2 [ctx::selection ids NodesSelector2]

    if {[ctx::selection count SystemsSelector]} {
        set sys [ctx::selection ids SystemsSelector]
    } else {set sys 0}

    if {[llength $nodes1] == 1 || [llength $nodes2] == 1} {
        Message "Please select multiple nodes in each selection!"
        return 0
    }

    set axis [ctx GetOption axis]
    set type [ctx GetOption type]

    set comp_name [ctx GetOption comp_name]
    if {![set comp [HmToolkit::Query exist comps name=$comp_name]]} {set comp [HmToolkit::Modify Create comps $comp_name]}
    *currentcollector comp $comp_name

    set r1 [HmToolkit::Modify Create Rbe2 $nodes1]
    set n1 [hm_getvalue elems id=$r1 dataname=independentnode]
    set r2 [HmToolkit::Modify Create Rbe2 $nodes2]
    set n2 [hm_getvalue elems id=$r2 dataname=independentnode]

    switch $type {
        "Rbe2-Beam" {
            set radius [ctx GetOption radius]

            set comp_beam $comp_name-Beam
            if {![set comp [HmToolkit::Query exist comps name=$comp_beam]]} {set comp [HmToolkit::Modify Create comps $comp_beam]}
            *currentcollector comp $comp_beam
            set beam_section [HmToolkit::Modify Create beam_section "Rod-R$radius" Rod $radius]
            set mat [HmToolkit::Modify Create mat Steel -E 210000 -G 80769.2 -NU 0.3 -RHO 7.85e-09]
            set beam_prop [HmToolkit::Modify Create beam_property "Beam-Rod-R$radius" $beam_section $mat]
            *setvalue comps id=$comp propertyid=$beam_prop

            set coord1 [HmToolkit::Query get_coord $n1 nodes $sys]
            set coord2 [HmToolkit::Query get_coord $n2 nodes $sys]

            switch $axis {
                X {
                    set y1 [lindex $coord1 1]
                    set z1 [lindex $coord1 2]
                    set y2 [lindex $coord2 1]
                    set z2 [lindex $coord2 2]
                    set new_coord1 [list [lindex $coord1 0] [expr {($y1+$y2)/2.0}] [expr {($z1+$z2)/2.0}]]
                    set new_coord2 [list [lindex $coord2 0] [expr {($y1+$y2)/2.0}] [expr {($z1+$z2)/2.0}]]
                }
                Y {
                    set x1 [lindex $coord1 0]
                    set z1 [lindex $coord1 2]
                    set x2 [lindex $coord2 0]
                    set z2 [lindex $coord2 2]
                    set new_coord1 [list [expr {($x1+$x2)/2.0}] [lindex $coord1 1] [expr {($z1+$z2)/2.0}]]
                    set new_coord2 [list [expr {($x1+$x2)/2.0}] [lindex $coord2 1] [expr {($z1+$z2)/2.0}]]
                }
                Z {
                    set x1 [lindex $coord1 0]
                    set y1 [lindex $coord1 1]
                    set x2 [lindex $coord2 0]
                    set y2 [lindex $coord2 1]
                    set new_coord1 [list [expr {($x1+$x2)/2.0}] [expr {($y1+$y2)/2.0}] [lindex $coord1 2]]
                    set new_coord2 [list [expr {($x1+$x2)/2.0}] [expr {($y1+$y2)/2.0}] [lindex $coord2 2]]
                }
                default {return 0}
            }

            HmToolkit::Modify position nodes $n1 $coord1 $new_coord1 $sys
            HmToolkit::Modify position nodes $n2 $coord2 $new_coord2 $sys

            set beam [HmToolkit::Modify Create beam $n1 $n2 4 4]
        }
        "Rbe2-Spring" {
            set comp_spring $comp_name-Spring
            if {![set comp [HmToolkit::Query exist comps name=$comp_spring]]} {set comp [HmToolkit::Modify Create comps $comp_spring]}
            *currentcollector comp $comp_spring

            set coord1 [HmToolkit::Query get_coord $n1 nodes $sys]
            set coord2 [HmToolkit::Query get_coord $n2 nodes $sys]
            switch $axis {
                X {
                    set spring_prop [HmToolkit::Modify Create bush_property $comp_spring "-1 -1 -1 0 -1 -1"]
                    *setvalue comps id=$comp propertyid=$spring_prop

                    set y1 [lindex $coord1 1]
                    set z1 [lindex $coord1 2]
                    set y2 [lindex $coord2 1]
                    set z2 [lindex $coord2 2]
                    set new_coord1 [list [lindex $coord1 0] [expr {($y1+$y2)/2.0}] [expr {($z1+$z2)/2.0}]]
                    set new_coord2 [list [lindex $coord2 0] [expr {($y1+$y2)/2.0}] [expr {($z1+$z2)/2.0}]]
                }
                Y {
                    set spring_prop [HmToolkit::Modify Create bush_property $comp_spring "-1 -1 -1 0 -1 -1"]
                    *setvalue comps id=$comp propertyid=$spring_prop

                    set x1 [lindex $coord1 0]
                    set z1 [lindex $coord1 2]
                    set x2 [lindex $coord2 0]
                    set z2 [lindex $coord2 2]
                    set new_coord1 [list [expr {($x1+$x2)/2.0}] [lindex $coord1 1] [expr {($z1+$z2)/2.0}]]
                    set new_coord2 [list [expr {($x1+$x2)/2.0}] [lindex $coord2 1] [expr {($z1+$z2)/2.0}]]
                }
                Z {
                    set spring_prop [HmToolkit::Modify Create bush_property $comp_spring "-1 -1 -1 0 -1 -1"]
                    *setvalue comps id=$comp propertyid=$spring_prop

                    set x1 [lindex $coord1 0]
                    set y1 [lindex $coord1 1]
                    set x2 [lindex $coord2 0]
                    set y2 [lindex $coord2 1]
                    set new_coord1 [list [expr {($x1+$x2)/2.0}] [expr {($y1+$y2)/2.0}] [lindex $coord1 2]]
                    set new_coord2 [list [expr {($x1+$x2)/2.0}] [expr {($y1+$y2)/2.0}] [lindex $coord2 2]]
                }
                default {return 0}
            }

            HmToolkit::Modify position nodes $n1 $coord1 $new_coord1 $sys
            HmToolkit::Modify position nodes $n2 $coord2 $new_coord2 $sys

            set spring [HmToolkit::Modify Create spring $n1 $n2]
        }
    }

    return 1
}

ctx::manager register hm CreateJointCtx "::HmToolkit::CreateJointCtx"
puts "register: HmToolkit::CreateJointCtx"