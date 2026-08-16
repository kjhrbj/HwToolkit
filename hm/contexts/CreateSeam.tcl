if {[itcl::is class ::HmToolkit::CreateSeamCtx]} {itcl::delete class ::HmToolkit::CreateSeamCtx}

itcl::class ::HmToolkit::CreateSeamCtx {
    inherit ::hm::context::HMScriptableBase
    constructor {args} {}

    public method proceed {args}
    public method ok {args}
    public method cancel {args}

    public method OnPost {args}
    public method OnUnpost {args}
    public method OnSelectionChange {args}
    public method AutoProceed {args}

    public method reverse {args}
    public method auto_seam_height {args}

    private method __perform {args}
    private method __preview {args}

    private variable source_lines {}
    private variable project_lines1 {}
    private variable project_lines2 {}
    private variable seam_height 0

    private variable temp_comp 0
}

itcl::body ::HmToolkit::CreateSeamCtx::proceed {args} {
    if {![ctx::selection count SurfSelector] || ![ctx::selection count LineSelector]} {return 0}

    ctx StartRecordHistory "Create Seam"
    if {[catch {__perform} error_info]} {
        ctx EndRecordHistory "Create Seam"
        ctx undo
        Message "Function failed for unknown reason!\nerror info:$error_info"

        ctx::selection clear SurfSelector
        ctx::selection clear LineSelector

        ctx SetActiveSelection LineSelector

        return 0
    } else {
        ctx EndRecordHistory "Create Seam"

        ctx::selection clear SurfSelector
        ctx::selection clear LineSelector

        ctx SetActiveSelection LineSelector

        return $error_info
    }
}

itcl::body ::HmToolkit::CreateSeamCtx::ok {args} {
    if {[proceed]} {ctx::manager exit}
}

itcl::body ::HmToolkit::CreateSeamCtx::cancel {args} {
    ctx::manager exit
}

itcl::body ::HmToolkit::CreateSeamCtx::OnPost {args} {
    ctx::ui post pp
    auto_seam_height
    ctx StartRecordHistory "Set Seam Component"
    set comp_name "SeamTemp"
    if {![set temp_comp [HmToolkit::Query exist comps name=$comp_name]]} {set temp_comp [HmToolkit::Modify Create comps $comp_name]}
    *currentcollector components $comp_name

    *createmark components 1 $comp_name
    *setvalue comps mark=1 color=#FF0000
    *createstringarray 2 "elements_off" "geometry_on"
    *showentitybymark 1 1 2
    *plot
    ctx EndRecordHistory "Set Seam Component"
}

itcl::body ::HmToolkit::CreateSeamCtx::OnUnpost {args} {
    ctx StartRecordHistory "Delete Temporary Data"
    HmToolkit::Modify Delete lines [concat $source_lines $project_lines1 $project_lines2]
    HmToolkit::Modify Delete comps $temp_comp
    ctx EndRecordHistory "Delete Temporary Data"
}

itcl::body ::HmToolkit::CreateSeamCtx::AutoProceed {args} {
    if {[proceed]} {
        ctx SetActiveSelection SurfSelector
    }
}

itcl::body ::HmToolkit::CreateSeamCtx::OnSelectionChange {args} {
    if {[ctx::selection count LineSelector] && [ctx::selection count SurfSelector]} {
        # 预览功能
        ctx StartRecordHistory "Create Seam Preview"
        if {[catch {__preview} error_info]} {
            ctx EndRecordHistory "Create Seam Preview"
            ctx Undo
            Message "Fail in preview process!\nError info:$error_info"
        } else {
            ctx EndRecordHistory "Create Seam Preview"
            if {!$error_info} {ctx Undo}
        }
    }
}

itcl::body ::HmToolkit::CreateSeamCtx::reverse {args} {
    set angle [ctx GetOption angle]
    ctx SetOption angle [expr -$angle]
    OnSelectionChange
}

itcl::body ::HmToolkit::CreateSeamCtx::auto_seam_height {args} {
    set auto_height [ctx GetOption auto_height]
    if {$auto_height} {
        ctx::ui set height -state disable
    } else {
        ctx::ui set height -state normal
    }
    OnSelectionChange
}

itcl::body ::HmToolkit::CreateSeamCtx::__perform {args} {

    set lines [ctx::selection ids LineSelector]
    set target_surf [ctx::selection ids SurfSelector]
    set source_surfs {}

    foreach l $lines {
        lappend source_surfs {*}[hm_getsurfacesfromedge $l]
    }

    if {[llength $project_lines1] == 0 && [llength $project_lines2] == 0} {
        Message "Invalid Input to Create Seams!"
        return 0
    }

    set thickness [format "%d" [expr round($seam_height)]]
    if {$thickness > 0} {set comp_name "Seam-H$thickness"} else {set comp_name "Seam-WithoutThickness"}
    if {![set comp [HmToolkit::Query exist comps name=$comp_name]]} {
        set comp [HmToolkit::Modify Create comps $comp_name]
        set mat [HmToolkit::Modify Create material Seam-Steel -E 210000 -G 80769.2 -NU 0.3 -RHO 7.85e-09]
        set prop [HmToolkit::Modify Create shell_property Seam-H$thickness $thickness $mat]
        *setvalue comps id=$comp propertyid=$prop
        *createmark components 1 $comp_name; *setvalue comps mark=1 color=#FF0000
    }
    *currentcollector components $comp_name

    set adj_edge_info {}
    set n [llength $source_lines]
    for {set i 0} {$i < $n} {incr i} {
        set ei [lindex $lines $i]
        dict append adj_edge_info $i {}
        set adj_edges [HmToolkit::Query adjacent_edges $ei]
        for {set j [expr $i + 1]} {$j < $n} {incr j} {
            set ej [lindex $lines $j]
            if {$ej in $adj_edges} {dict lappend adj_edge_info $i $j}
        }
    }

    set seam_surfs {}
    set supplement_seam {}

    for {set i 0} {$i < $n} {incr i} {
        set s1 [lindex $source_lines $i]
        set s2 [HmToolkit::Modify Duplicate lines $s1]
        set p1 [lindex $project_lines1 $i]
        set p2 [lindex $project_lines2 $i]

        if {$p1 ne ""} {
            set lp [hm_getvalue lines id=$p1 dataname=length]
            set ls [hm_getvalue lines id=$s1 dataname=length]
            if {[expr $lp / $ls] < 0.99} {
                set s1 [HmToolkit::Modify project_line_to_line $p1 $s1]
            }

            if {$s1} {              
                lappend seam_surfs [HmToolkit::Modify patch "$p1 $s1"]
                set adj_edges_index [dict get $adj_edge_info $i]
                if {[llength $adj_edges_index]} {
                    foreach index $adj_edges_index {
                        set adj_e [lindex $project_lines1 $index]                        
                        set rv [hm_getclosestpointsbetweentwolines $p1 $adj_e]
                        set coord1 [lrange $rv 0 2]
                        set coord2 [lrange $rv 3 5]
                        set dist [HmToolkit::Query get_dist $coord1 $coord2]
                        if {$dist < [expr max($seam_height / 5.0 , 0.5)]} {continue}
                        set coord3 [lrange [hm_findclosestpointonline {*}$coord1 $s1] 0 2]
                        set coords {}
                        lappend coords $coord1 $coord2 $coord3
                        lappend supplement_seam [HmToolkit::Modify patch_coords $coords]
                    }
                }
            }

        }

        if {$p2 ne ""} {
            set lp [hm_getvalue lines id=$p2 dataname=length]
            set ls [hm_getvalue lines id=$s2 dataname=length]
            if {[expr $lp / $ls] < 0.99} {
                set s2 [HmToolkit::Modify project_line_to_line $p2 $s2]
            }
            if {$s2} {
                lappend seam_surfs [HmToolkit::Modify patch "$p2 $s2"]

                set adj_edges_index [dict get $adj_edge_info $i]
                if {[llength $adj_edges_index]} {
                    foreach index $adj_edges_index {
                        set adj_e [lindex $project_lines2 $index]
                        set rv [hm_getclosestpointsbetweentwolines $p2 $adj_e]
                        set coord1 [lrange $rv 0 2]
                        set coord2 [lrange $rv 3 5]
                        set dist [HmToolkit::Query get_dist $coord1 $coord2]
                        if {$dist < [expr max($seam_height / 5.0 , 0.5)]} {continue}
                        set coord3 [lrange [hm_findclosestpointonline {*}$coord1 $s2] 0 2]
                        set coords {}
                        lappend coords $coord1 $coord2 $coord3
                        lappend supplement_seam [HmToolkit::Modify patch_coords $coords]
                    }
                }

            }
        }

        HmToolkit::Modify Delete lines "$s1 $s2"
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

    HmToolkit::Modify surfs_stitch $seam_surfs [expr max($seam_height / 5.0 , 0.5)]
    HmToolkit::Modify surfs_stitch [concat $seam_surfs $source_surfs $target_surf $supplement_seam] 0.1

    *clearmark surfs 1
    return 1
}

itcl::body ::HmToolkit::CreateSeamCtx::__preview {args} {
    set lines [ctx::selection ids LineSelector]
    set target_surf [ctx::selection ids SurfSelector]
    set source_surf [hm_getsurfacesfromedge [lindex $lines 0]]

    if {[llength $source_surf] != 1} {
        set tseam 0
        set source_surf [lindex $source_surf 0]
    } else {
        set coord [hm_getvalue lines id=[lindex $lines 0] dataname=startcoords]
        set tangle [HmToolkit::Query get_angle_surf_surf $source_surf $target_surf $coord]
        if {$tangle > 75 && $tangle < 105} {set tseam 1} else {set tseam 0}
    }

    set angle [ctx GetOption angle]
    set double [ctx GetOption double]
    set auto_height [ctx GetOption auto_height]
    set offset_flag [ctx GetOption offset_flag]

    if {$auto_height} {
        set target_thickness [HmToolkit::Query get_thickness_surf $target_surf 1]
        set source_thickness [HmToolkit::Query get_thickness_surf $source_surf 1]
        set seam_height [expr min ($source_thickness, $target_thickness)]
    } else {set seam_height [ctx GetOption height]}

    HmToolkit::Modify Delete lines [concat $source_lines $project_lines1 $project_lines2]
    set project_lines1 {}
    set project_lines2 {}
    set source_lines {}

    *currentcollector components "SeamTemp"

    if {$tseam} {
        foreach l $lines {
            if {[hm_getvalue lines id=$l dataname=topologytype] ne "free"} {
                lappend source_lines [HmToolkit::Modify Duplicate lines $l]
            } else {
                set rv [hm_getclosestpointsbetweenlinesurface $l $target_surf]
                if {[llength $rv] == 7} {set dist [lindex $rv end]} else {set dist 0}
                set offset [expr ($seam_height) - $dist]
                if {!$offset_flag} {set offset -1}
                if {$offset < 0.5} {
                    lappend source_lines [HmToolkit::Modify Duplicate lines $l]
                } else {
                    lappend source_lines [HmToolkit::Modify offset_edge $l $offset]
                }
            }
        }
    } else {set source_lines [HmToolkit::Modify Duplicate lines $lines]}

    foreach source $source_lines { 
        if {[HmToolkit::Query iscurve $source]} {
            lappend project_lines1 [HmToolkit::Modify project_curve_line_to_surf $source $target_surf $angle]
            if {$double} {lappend project_lines2 [HmToolkit::Modify project_curve_line_to_surf $source $target_surf [expr -$angle]]}
        } else {
            set p1 [HmToolkit::Modify Duplicate lines $source]

            set vec1 [HmToolkit::Query get_project_vector $p1 $target_surf $angle]

            set p1 [HmToolkit::Modify project_entities_to_surf lines $p1 $target_surf $vec1]

            if {![HmToolkit::Query same_line $p1 $source]} {lappend project_lines1 $p1} else {
                HmToolkit::Modify Delete lines $p1
                lappend project_lines1 ""
            }

            if {$double} {
                set p2 [HmToolkit::Modify Duplicate lines $source]
                set vec2 [HmToolkit::Query get_project_vector $p2 $target_surf [expr -$angle]]
                set p2 [HmToolkit::Modify project_entities_to_surf lines $p2 $target_surf $vec2]

                if {![HmToolkit::Query same_line $p2 $source]} {lappend project_lines2 $p2} else {
                    HmToolkit::Modify Delete lines $p2
                    lappend project_lines2 ""
                }
            }

        }
    }

    return 1
}

ctx::manager register hm CreateSeamCtx "::HmToolkit::CreateSeamCtx"
puts "register: HmToolkit::CreateSeamCtx"