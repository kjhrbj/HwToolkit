if {[itcl::is class ::HmToolkit::AutoSeamCtx]} { itcl::delete class ::HmToolkit::AutoSeamCtx}

itcl::class ::HmToolkit::AutoSeamCtx {
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
    private method __check_target {source_surf target_surf}
    private method __check_edge {edge source target}
    private method __create_seam {line target}
}

itcl::body ::HmToolkit::AutoSeamCtx::proceed {args} {
    if {![ctx::selection count SurfsSelector]} {return 0}
    ctx StartRecordHistory "Auto Seam"
    if {[catch {__perform} error_info]} {
        #ctx EndRecordHistory "Auto Seam"
        ctx::selection clear SurfsSelector
        ctx SetActiveSelection SurfsSelector
        Message "Function failed for unknown reason!\nerror info:$error_info"
        return 0
    } else {
        ctx EndRecordHistory "Auto Seam" 
        # 这里有问题，有error抛出就不能EndRecordHistory
        ctx::selection clear SurfsSelector
        ctx SetActiveSelection SurfsSelector
        return 1
    }
}

itcl::body ::HmToolkit::AutoSeamCtx::ok {args} {
    if {[proceed]} {
        ctx::manager exit
    }
}

itcl::body ::HmToolkit::AutoSeamCtx::cancel {args} {
    ctx::manager exit
}

itcl::body ::HmToolkit::AutoSeamCtx::OnPost {args} {

}

itcl::body ::HmToolkit::AutoSeamCtx::OnUnpost {args} {

}

itcl::body ::HmToolkit::AutoSeamCtx::OnSelectionChange {args} {

}

itcl::body ::HmToolkit::AutoSeamCtx::AutoProceed {args} {
    proceed
}

itcl::body ::HmToolkit::AutoSeamCtx::__perform {args} {
    set MyerrorInfo 0
    set surfs [ctx::selection ids SurfsSelector]

    set tolerance [ctx GetOption tolerance]

    set seams_dict {}

    set comp_name "SeamTemp"
    if {![set temp_comp [HmToolkit::Query exist comps name=$comp_name]]} {set temp_comp [HmToolkit::Modify Create comps $comp_name]}
    *currentcollector components $comp_name

    set n [llength $surfs]
    for {set i 0} {$i < $n} {incr i} {
        set source [lindex $surfs $i]
        for {set j 0} {$j < $n} {incr j} {
            set target [lindex $surfs $j]

            if {$source == $target} {continue}

            if {![__check_target $source $target]} {continue}

            set edges [concat {*}[hm_getsurfaceedges $source]]
            foreach edge $edges {
                if {![__check_edge $edge $source $target]} {continue}
                if {[catch {__create_seam $edge $target} rv]} {
                    set MyerrorInfo 1
                    continue
                }
                if {[llength $rv] ne 2} {continue}
                set seam_height [lindex $rv 0]
                set seams [lindex $rv 1]
                dict lappend seams_dict $seam_height {*}$seams
            }
        }
    }

    if {![set bad_seams_comp [HmToolkit::Query exist comps name="BadSeams"]]} {set bad_seams_comp [HmToolkit::Modify Create comps "BadSeams"]}

    foreach {seam_height seams} $seams_dict {
        set thickness [format "%d" $seam_height]
        if {$thickness > 0} {set comp_name "Seam-H$seam_height"} else {set comp_name "Seam_WithoutThickness"}
        if {![set comp [HmToolkit::Query exist comps name=$comp_name]]} {
            set comp [HmToolkit::Modify Create comps $comp_name]
            set mat [HmToolkit::Modify Create material Seam-Steel -E 210000 -G 80769.2 -NU 0.3 -RHO 7.85e-09]
            set prop [HmToolkit::Modify Create shell_property Seam-H$seam_height $thickness $mat]
            *setvalue comps id=$comp propertyid=$prop  
            *createmark components 1 $comp_name
            *setvalue comps mark=1 color=#FF0000
        }
        *createmark surfs 1 {*}$seams
        *movemark surfs 1 $comp_name

        set bad_seams {}
        foreach seam $seams {
            set edges [concat {*}[hm_getsurfaceedges $seam]]
            set flag 1
            foreach edge $edges {
                set length [hm_linelength $edge]
                if {$length > [expr $seam_height]} {
                    set flag 0
                    break
                }
            }
            if {$flag} {
                lappend bad_seams $seam
            }
        }

        if {[llength $bad_seams]} {
            *createmark surfs 1 {*}$bad_seams
            *movemark surfs 1 "BadSeams"
        }

        HmToolkit::Support lremove seams $bad_seams

        if {![llength $seams]} {return 1}

        HmToolkit::Modify surfs_stitch $seams [expr min($seam_height * 0.1, 0.5)]
    }

    HmToolkit::Modify Delete comps $temp_comp

    if {$MyerrorInfo} {error "error happended in seams creating process"}

    return 1
}

itcl::body ::HmToolkit::AutoSeamCtx::__check_target {source_surf target_surf} {
    if {[HmToolkit::Query iscurvesurf $target_surf]} {return 0}
    set tolerance [ctx GetOption tolerance]
    set t [HmToolkit::Query get_thickness_surf $target_surf 1]
    set t [expr $t * 0.6]
    set tolerance [expr min($t, $tolerance)]

    if {$target_surf in [HmToolkit::Query attach_entities surfs $source_surf]} {return 0}
    set shortest_dist [HmToolkit::Query shortest_dist surfs $target_surf surfs $source_surf]
    if {$shortest_dist > $tolerance} {return 0}
    if {$shortest_dist < 0.1} {return 0}
    return 1
}

itcl::body ::HmToolkit::AutoSeamCtx::__check_edge {edge source target} {
    if {[hm_getvalue lines id=$edge dataname=topologytype] ne "free"} {return 0}
    set tolerance [ctx GetOption tolerance]

    set t [HmToolkit::Query get_thickness_surf $target 1]
    set t [expr $t * 0.6]
    set tolerance [expr min($t, $tolerance)]

    set rv [hm_getclosestpointsbetweenlinesurface $edge $target]
    set surf_point [lrange $rv 0 2]
    set v1 [HmToolkit::Support Vector sub [lrange $rv 0 2] [lrange $rv 3 5]]
    set v1 [HmToolkit::Support Vector normalize $v1]
    set v2 [lrange [hm_getsurfacenormalatcoordinate $target {*}$surf_point] 3 5]
    set v2 [HmToolkit::Support Vector normalize $v2]
    set dot [expr abs([HmToolkit::Support Vector dot $v1 $v2])]
    if {$dot < 0.99} {return 0}

    set dist [lindex $rv 6]
    if {$dist > $tolerance} {return 0}

    set startcoord [hm_getvalue lines id=$edge dataname=startcoords]
    set angle [HmToolkit::Query get_angle_surf_surf $source $target $startcoord]
    if {$angle < 75 || $angle > 105} {return 0}

    set angle1 [HmToolkit::Query get_angle_line_surf_start $edge $target]
    if {$angle1 < 75 || $angle1 > 105} {return 0}
    set angle2 [HmToolkit::Query get_angle_line_surf_end $edge $target]
    if {$angle2 < 75 || $angle2 > 105} {return 0}

    return 1
}

itcl::body ::HmToolkit::AutoSeamCtx::__create_seam {line target} {
    set angle 45

    set project_line1 0
    set project_line2 0
    set project_line3 0

    set type [ctx GetOption type]
    if {[HmToolkit::Query iscurve $line]} {
        if {$type eq "Seam"} {
            set project_line1 [HmToolkit::Modify project_curve_line_to_surf $line $target $angle]
            set project_line2 [HmToolkit::Modify project_curve_line_to_surf $line $target [expr -$angle]]
        } elseif {$type eq "Extension"} {set project_line3 [HmToolkit::Modify project_curve_line_to_surf $line $target 0]} elseif {$type eq "Seam+Extension"} {
            set project_line1 [HmToolkit::Modify project_curve_line_to_surf $line $target $angle]
            set project_line2 [HmToolkit::Modify project_curve_line_to_surf $line $target [expr -$angle]]
            set project_line3 [HmToolkit::Modify project_curve_line_to_surf $line $target 0]
        }
    } else {
        if {$type eq "Seam"} {
            set project_line1 [HmToolkit::Modify Duplicate lines $line]
            set vec1 [HmToolkit::Query get_project_vector $project_line1 $target $angle]
            set project_line1 [HmToolkit::Modify project_entities_to_surf lines $project_line1 $target $vec1]
            if {[HmToolkit::Query same_line $project_line1 $line]} {set project_line1 0}

            set project_line2 [HmToolkit::Modify Duplicate lines $line]
            set vec2 [HmToolkit::Query get_project_vector $project_line2 $target [expr - $angle]]
            set project_line2 [HmToolkit::Modify project_entities_to_surf lines $project_line2 $target $vec2]
            if {[HmToolkit::Query same_line $project_line2 $line]} {set project_line2 0}
        } elseif {$type eq "Extension"} {
            set project_line3 [HmToolkit::Modify Duplicate lines $line]
            set project_line3 [HmToolkit::Modify project_entities_to_surf lines $project_line3 $target]
            if {[HmToolkit::Query same_line $project_line3 $line]} {set project_line3 0}
        } elseif {$type eq "Seam+Extension"} {
            set project_line1 [HmToolkit::Modify Duplicate lines $line]
            set vec1 [HmToolkit::Query get_project_vector $project_line1 $target $angle]
            set project_line1 [HmToolkit::Modify project_entities_to_surf lines $project_line1 $target $vec1]
            if {[HmToolkit::Query same_line $project_line1 $line]} {set project_line1 0}

            set project_line2 [HmToolkit::Modify Duplicate lines $line]
            set vec2 [HmToolkit::Query get_project_vector $project_line2 $target [expr - $angle]]
            set project_line2 [HmToolkit::Modify project_entities_to_surf lines $project_line2 $target $vec2]
            if {[HmToolkit::Query same_line $project_line2 $line]} {set project_line2 0}

            set project_line3 [HmToolkit::Modify Duplicate lines $line]
            set project_line3 [HmToolkit::Modify project_entities_to_surf lines $project_line3 $target]
            if {[HmToolkit::Query same_line $project_line3 $line]} {set project_line3 0}
        }
    }
    if {!$project_line1 && !$project_line2 && !$project_line3} {return 0}

    set source_surfs {}
    lappend source_surfs {*}[hm_getsurfacesfromedge $line]

    set seam_height inf
    foreach source $source_surfs {
        set surf_thickness [HmToolkit::Query get_thickness_surf $source 1]
        if {$surf_thickness < $seam_height} {set seam_height $surf_thickness}
    }
    set surf_thickness [HmToolkit::Query get_thickness_surf $target 1]
    set seam_height [expr round(min($surf_thickness, $seam_height))]

    set seams {}
    if {$project_line1} {
        set s1 [HmToolkit::Modify Duplicate lines $line]
        set s1 [HmToolkit::Modify project_line_to_line $project_line1 $s1]
        if {$s1} {
            lappend seams [HmToolkit::Modify patch "$project_line1 $s1"]
        }
    }

    if {$project_line2} {
        set s2 [HmToolkit::Modify Duplicate lines $line]
        set s2 [HmToolkit::Modify project_line_to_line $project_line2 $s2]
        if {$s2} {
            lappend seams [HmToolkit::Modify patch "$project_line2 $s2"]
        }
    }

    if {$project_line3} {
        set s3 [HmToolkit::Modify Duplicate lines $line]
        set s3 [HmToolkit::Modify project_line_to_line $project_line3 $s3]
        if {$s3} {
            lappend seams [HmToolkit::Modify patch "$project_line3 $s3"]
        }
    }
    return [lappend {} $seam_height $seams]
}

ctx::manager register hm AutoSeamCtx "::HmToolkit::AutoSeamCtx"
puts "register: HmToolkit::AutoSeamCtx"