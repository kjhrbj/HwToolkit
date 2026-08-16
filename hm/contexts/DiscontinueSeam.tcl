if {[itcl::is class ::HmToolkit::DiscontinueSeamCtx]} {
    itcl::delete class ::HmToolkit::DiscontinueSeamCtx
}

itcl::class ::HmToolkit::DiscontinueSeamCtx {
    inherit ::hm::context::HMScriptableBase
    constructor {args} {}

    public method proceed {args}
    public method ok {args}
    public method cancel {args}

    public method OnPost {args}
    public method OnUnpost {args}
    public method OnSelectionChange {args}
    public method AutoProceed {args}

    public method set_type {args}
    public method set_parameter {para_name}
    public method reverse {args}
    public method auto_height {args}

    private method __perform {args}
    private method __preview {args}

    private variable source_lines {}
    private variable project_lines1 {}
    private variable project_lines2 {}
    private variable seam_height 0
    private variable offset_line 0

    private variable vec1
    private variable vec2

    private variable temp_comp 0
    private variable parameters {angle 45 height 0 double false length 20 interval 20 type Number number 5 auto_height 1}
}

itcl::body ::HmToolkit::DiscontinueSeamCtx::proceed {args} {
    ctx StartRecordHistory "Create Discontinue Seam"
    if {[catch {__perform} res]} {
        ctx EndRecordHistory "Create Discontinue Seam"
        ctx Undo

        ctx::selection clear SurfSelector
        ctx::selection clear LineSelector
        ctx::selection clear PointSelector

        ctx SetActiveSelection LineSelector

        Message "Function failed for unknown reason!\nerror info:$error_info"
        return 0
    } else {
        ctx EndRecordHistory "Create Discontinue Seam"

        ctx::selection clear SurfSelector
        ctx::selection clear LineSelector
        ctx::selection clear PointSelector

        ctx SetActiveSelection LineSelector

        return $res
    }
}

itcl::body ::HmToolkit::DiscontinueSeamCtx::ok {args} {
    if {[proceed]} {ctx::manager exit}
}

itcl::body ::HmToolkit::DiscontinueSeamCtx::cancel {args} {
    ctx::manager exit
}

itcl::body ::HmToolkit::DiscontinueSeamCtx::OnPost {args} {
    ctx::ui post pp
    auto_height
    set comp_name "SeamTemp"
    ctx StartRecordHistory "Create Temporary Component"
    if {![set temp_comp [HmToolkit::Query exist comps name=$comp_name]]} {set temp_comp [HmToolkit::Modify Create comps $comp_name]}
    *currentcollector components $comp_name

    *createmark components 1 $comp_name
    *setvalue comps mark=1 color=#FF0000
    *clearmark components 1

    *plot
    ctx EndRecordHistory "Create Temporary Component"

}

itcl::body ::HmToolkit::DiscontinueSeamCtx::OnUnpost {args} {
    ctx StartRecordHistory "Delete Temporary Data"
    HmToolkit::Modify Delete comps $temp_comp
    HmToolkit::Modify Delete lines [concat $source_lines $project_lines1 $project_lines2]
    ctx EndRecordHistory "Delete Temporary Data"
}

itcl::body ::HmToolkit::DiscontinueSeamCtx::AutoProceed {args} {
    if {[ctx::selection count SurfSelector] && [ctx::selection count LineSelector]} {
        proceed
        ctx SetActiveSelection PointSelector
    }
}

itcl::body ::HmToolkit::DiscontinueSeamCtx::OnSelectionChange {args} {
    if {[ctx::selection count LineSelector] && [ctx::selection count SurfSelector]} {
        ctx StartRecordHistory "Discontinue Seam Preview"
        if {[catch {__preview} error_info]} {
            ctx EndRecordHistory "Discontinue Seam Preview"
            #ctx Undo
            Message "Fail in preview process!\nError info:$error_info"
        } else {ctx EndRecordHistory "Discontinue Seam Preview"}
    } elseif {[ctx::selection count LineSelector] || [ctx::selection count SurfSelector]} {
        if {![ctx::ui get dialog visible]} {ctx::ui post dialog}
    } else {
        ctx::ui unpost dialog
    }
}

itcl::body ::HmToolkit::DiscontinueSeamCtx::set_type {args} {
    set type [ctx GetOption type]
    switch $type {
        Number {
            ctx::ui set interval -visible 0
            ctx::ui set number -visible 1
        }
        Interval {
            ctx::ui set number -visible 0
            ctx::ui set interval -visible 1
        }
    }
}

itcl::body ::HmToolkit::DiscontinueSeamCtx::set_parameter {para_name} {
    set old_value [dict get $parameters $para_name]
    set new_value [ctx GetOption $para_name]
    if {$new_value eq $old_value} {return}
    dict set parameters $para_name $new_value
    OnSelectionChange
}

itcl::body ::HmToolkit::DiscontinueSeamCtx::reverse {args} {
    set angle [ctx GetOption angle]
    ctx SetOption angle [expr -$angle]
    OnSelectionChange
}

itcl::body ::HmToolkit::DiscontinueSeamCtx::auto_height {args} {
    set auto_height [ctx GetOption auto_height]
    if {$auto_height} {
        ctx::ui set height -state disable
    } else {
        ctx::ui set height -state normal
    }
}

itcl::body ::HmToolkit::DiscontinueSeamCtx::__preview {args} {
    set line [ctx::selection ids LineSelector]
    set target_surf [ctx::selection ids SurfSelector]
    set source_surf [hm_getsurfacesfromedge $line]

    if {[llength $source_surf] != 1} {
        set tseam 0
    } else {
        set coord [hm_getvalue lines id=$line dataname=startcoords]
        set angle [HmToolkit::Query get_angle_surf_surf $source_surf $target_surf $coord]
        if {$angle > 75 && $angle < 105} {set tseam 1} else {set tseam 0}
    }

    set angle [ctx GetOption angle]
    set auto_height [ctx GetOption auto_height]
    set offset_flag [ctx GetOption offset_flag]

    if {$auto_height} {
        set target_thickness [HmToolkit::Query get_thickness_surf $target_surf 1]
        set source_thickness [HmToolkit::Query get_thickness_surf $source_surf 1]
        set seam_height [expr min ($source_thickness, $target_thickness)]
    } else {set seam_height [ctx GetOption height]}
    set length [ctx GetOption length]
    set interval [ctx GetOption interval]
    set offset 0
    set type [ctx GetOption type]
    if {$type eq "Number"} {
        set number [ctx GetOption number]
    } else {set number 0}
    set double [ctx GetOption double]

    HmToolkit::Modify Delete lines [concat $source_lines $project_lines1 $project_lines2]
    set source_lines {}
    set project_lines1 {}
    set project_lines2 {}
    set offset_line 0

    *currentcollector components "SeamTemp"

    if {$tseam && [hm_getvalue lines id=$line dataname=topologytype] eq "free"} {
        set rv [hm_getclosestpointsbetweenlinesurface $line $target_surf]
        if {[llength $rv] == 7} {set dist [lindex $rv end]} else {set dist 0}
        set offset  [expr ($seam_height) - $dist]
        if {!$offset_flag} {set offset -1}
        if {$offset > 0.5} {
            set offset_line [HmToolkit::Modify offset_edge $line $offset]
            set point_selector [ctx GetNamedHMSelection "PointSelector"]
            if {[$point_selector IsEmpty]} { set point_coords [hm_getvalue lines id=$offset_line dataname=startcoords]} else {
                set point_coords [lindex [lindex [$point_selector GetLocations] 0] 0]
                set point_coords [lrange [hm_findclosestpointonline {*}$point_coords $offset_line] 0 2]
            }
            set source_lines [HmToolkit::Modify discontinue_seam $offset_line $point_coords $length $interval $number]
        } else {
            set point_selector [ctx GetNamedHMSelection "PointSelector"]
            if {![$point_selector IsEmpty]} {
                set point_coords [lindex [lindex [$point_selector GetLocations] 0] 0] 
                set point_coords [lrange [hm_findclosestpointonline {*}$point_coords $line] 0 2]
            } else {set point_coords [hm_getvalue lines id=$line dataname=startcoords]}
            set source_lines [HmToolkit::Modify discontinue_seam $line $point_coords $length $interval $number]
        }
    } else {
        set point_selector [ctx GetNamedHMSelection "PointSelector"]
        if {![$point_selector IsEmpty]} {
            set point_coords [lindex [lindex [$point_selector GetLocations] 0] 0]
            set point_coords [lrange [hm_findclosestpointonline {*}$point_coords $line] 0 2]
        } else {set point_coords [hm_getvalue lines id=$line dataname=startcoords]}
        set source_lines [HmToolkit::Modify discontinue_seam $line $point_coords $length $interval $number]
    }

    if {[llength $source_lines] == 0} {return 0}

    set vec1 [HmToolkit::Query get_project_vector $line $target_surf $angle]
    set vec2 [HmToolkit::Query get_project_vector $line $target_surf [expr -$angle]]

    foreach s_line $source_lines {
        set p1 [HmToolkit::Modify Duplicate lines $s_line]
        set p1 [HmToolkit::Modify project_entities_to_surf lines $p1 $target_surf $vec1]
        if {[llength $p1] != 1} {
            *linecombine [lindex $p1 0] [lindex $p1 end] 1
            set p1 [HmToolkit::Support currentids lines 1]
            HmToolkit::Modify Delete lines [lrange $p1 1 end-1]
        }
        if {![HmToolkit::Query same_line $p1 $s_line]} {lappend project_lines1 $p1} else {
            HmToolkit::Modify Delete lines $p1
            lappend project_lines1 ""
        }

        if {$double} {
            set p2 [HmToolkit::Modify Duplicate lines $s_line]
            set p2 [HmToolkit::Modify project_entities_to_surf lines $p2 $target_surf $vec2]
            if {[llength $p2] != 1} {
                *linecombine [lindex $p2 0] [lindex $p2 end] 1
                set p2 [HmToolkit::Support currentids lines 1]
                HmToolkit::Modify Delete lines [lrange $p2 1 end-1]
            }
            if {![HmToolkit::Query same_line $p2 $s_line]} {lappend project_lines2 $p2} else {
                HmToolkit::Modify Delete lines $p2
                lappend project_lines2 ""
            }
        }
    }

}

itcl::body ::HmToolkit::DiscontinueSeamCtx::__perform {args} {
    set line [ctx::selection ids LineSelector]
    set target_surf [ctx::selection ids SurfSelector]
    set source_surf [concat [hm_getsurfacesfromedge $line]]

    if {[llength $project_lines1] == 0 && [llength $project_lines2] == 0} {
        Message "Invalid Input to Create Seams!"
        return 0
    }

    set double [ctx GetOption double]
    set new_sources ￥source_surf
    if {$offset_line} {
        set p1 [HmToolkit::Modify Duplicate lines $offset_line]
        if {$double} {
            set p2 [HmToolkit::Modify Duplicate lines $offset_line]
        }
        set new_sources [HmToolkit::Modify split_surf_with_lines $source_surf $offset_line]
    } else {
        set p1 [HmToolkit::Modify Duplicate lines $line]
        if {$double} {
            set p2 [HmToolkit::Modify Duplicate lines $line]
        }
    }
    set split_lines [HmToolkit::Modify project_entities_to_surf lines $p1 $target_surf $vec1]
    if {$double} {lappend split_lines [HmToolkit::Modify project_entities_to_surf lines $p2 $target_surf $vec2]}
    set new_targets [HmToolkit::Modify split_surf_with_lines $target_surf $split_lines]

    set thickness [format "%d" [expr round($seam_height)]]
    if {$thickness > 0} {set comp_name "Seam-H$seam_height"} else {set comp_name "Seam-WithoutThickness"}
    if {![set comp [HmToolkit::Query exist comps name=$comp_name]]} {
        set comp [HmToolkit::Modify Create comps $comp_name]
        set mat [HmToolkit::Modify Create material Seam-Steel -E 210000 -G 80769.2 -NU 0.3 -RHO 7.85e-09]
        set prop [HmToolkit::Modify Create shell_property Seam-H$seam_height $thickness $mat]
        *setvalue comps id=$comp propertyid=$prop  
        *createmark components 1 $comp_name; *setvalue comps mark=1 color=#FF0000
    }
    *currentcollector components $comp_name

    set seam_surfs {}
    set n [llength $source_lines]
    for {set i 0} {$i < $n} {incr i} {
        set s1 [lindex $source_lines $i]
        set s2 [HmToolkit::Modify Duplicate lines $s1]
        set p1 [lindex $project_lines1 $i]
        set p2 [lindex $project_lines2 $i]
        if {$p1 ne ""} {
            lappend seam_surfs [HmToolkit::Modify patch "$p1 $s1"]
        }
        if {$p2 ne ""} {
            lappend seam_surfs [HmToolkit::Modify patch "$p2 $s2"]
        }
        HmToolkit::Modify Delete lines $s2
    }

    HmToolkit::Modify Delete lines [concat $source_lines $project_lines1 $project_lines2]
    set source_lines {}
    set project_lines1 {}
    set project_lines2 {}

    if {[llength $seam_surfs] == 0} {
        set rv [hm_getunusedoremptyentities mode=empty type=comps id=$comp outputmark=2]
        if {[llength $rv]} {HmToolkit::Modify Delete comps $comp}
        Message "No seam has been created, pleace check the input"
        return 0
    }

    HmToolkit::Modify surfs_stitch [concat $seam_surfs $new_sources $new_targets]

    *clearmark surfs 1

    return 1
}

ctx::manager register hm DiscontinueSeamCtx "::HmToolkit::DiscontinueSeamCtx"
puts "register: HmToolkit::DiscontinueSeamCtx"