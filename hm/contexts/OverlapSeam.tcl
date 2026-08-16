if {[itcl::is class ::HmToolkit::OverlapSeamCtx]} {itcl::delete class ::HmToolkit::OverlapSeamCtx}

itcl::class ::HmToolkit::OverlapSeamCtx {
    inherit ::hm::context::HMScriptableBase
    constructor {args} {}

    public method proceed {args}
    public method ok {args}
    public method cancel {args}

    public method OnPost {args}
    public method OnUnpost {args}
    public method OnSelectionChange {args}
    public method AutoProceed {args}

    public method auto_seam_height {args}

    private method __perform {args}

    private variable seam_height 0

    private variable temp_comp 0
}

itcl::body ::HmToolkit::OverlapSeamCtx::proceed {args} {
    if {![ctx::selection count LineSelector1] || ![ctx::selection count LineSelector2]} {return 0}

    ctx StartRecordHistory "Create Overlap Seam"
    if {[catch {__perform} error_info]} {
        ctx EndRecordHistory "Create Overlap Seam"
        Message "Function failed for unknown reason!\nerror info:$error_info"

        ctx::selection clear LineSelector1
        ctx::selection clear LineSelector2

        return 0
    } else {
        ctx EndRecordHistory "Create Overlap Seam"

        ctx::selection clear LineSelector1
        ctx::selection clear LineSelector2

        return 1
    }
}

itcl::body ::HmToolkit::OverlapSeamCtx::ok {args} {
    if {[proceed]} {ctx::manager exit}
}

itcl::body ::HmToolkit::OverlapSeamCtx::cancel {args} {
    ctx::manager exit
}

itcl::body ::HmToolkit::OverlapSeamCtx::OnPost {args} {
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

itcl::body ::HmToolkit::OverlapSeamCtx::OnUnpost {args} {
    ctx StartRecordHistory "Delete Temporary Data"
    HmToolkit::Modify Delete comps $temp_comp
    ctx EndRecordHistory "Delete Temporary Data"
}

itcl::body ::HmToolkit::OverlapSeamCtx::AutoProceed {args} {
    if {[proceed]} {
        ctx SetActiveSelection LineSelector2
    }
}

itcl::body ::HmToolkit::OverlapSeamCtx::auto_seam_height {args} {
    set auto_height [ctx GetOption auto_height]
    if {$auto_height} {
        ctx::ui set height -state disable
    } else {
        ctx::ui set height -state normal
    }
}

itcl::body ::HmToolkit::OverlapSeamCtx::__perform {args} {
    set source_lines [ctx::selection ids LineSelector1]
    set target_line [ctx::selection ids LineSelector2]

    set source_surfs {}
    foreach source_line $source_lines {
        lappend source_surfs [hm_getsurfacesfromedge $source_line]
    }
    set target_surf [hm_getsurfacesfromedge $target_line]

    set source_lines [HmToolkit::Modify Duplicate lines $source_lines]

    set seams {}

    foreach source_line $source_lines source_surf $source_surfs {
        set copy_target_line [HmToolkit::Modify Duplicate lines $target_line]

        set auto_height [ctx GetOption auto_height]
        if {$auto_height} {
            set target_thickness [HmToolkit::Query get_thickness_surf [lindex $target_surf 0] 1]
            set source_thickness [HmToolkit::Query get_thickness_surf [lindex $source_surf 0] 1]
            set seam_height [expr min ($source_thickness, $target_thickness)]
        } else {set seam_height [ctx GetOption height]}

        set thickness [format "%d" [expr round($seam_height)]]
        if {$thickness > 0} {set comp_name "Seam-H$thickness"} else {set comp_name "Seam_WithoutThickness"}
        if {![set comp [HmToolkit::Query exist comps name=$comp_name]]} {
            set comp [HmToolkit::Modify Create comps $comp_name]
            set mat [HmToolkit::Modify Create material Seam-Steel -E 210000 -G 80769.2 -NU 0.3 -RHO 7.85e-09]
            set prop [HmToolkit::Modify Create shell_property Seam-H$seam_height $thickness $mat]
            *setvalue comps id=$comp propertyid=$prop  
            *createmark components 1 $comp_name; *setvalue comps mark=1 color=#FF0000
        }
        *currentcollector components $comp_name

        set project_line1 [HmToolkit::Modify project_line_to_line $source_line $copy_target_line]
        set project_line2 [HmToolkit::Modify project_line_to_line $project_line1 $source_line]

        if {!$project_line1 || !$project_line2} {
            continue
        }
        lappend seams [HmToolkit::Modify patch "$project_line1 $project_line2"]

        HmToolkit::Modify Delete lines "$project_line1 $project_line2"
    }
    if {![llength $seams]} {
        Message "No seams has been created, please check input!"
        return 0
    }
    HmToolkit::Modify surfs_stitch "$seams $source_surfs $target_surf" [expr max($seam_height / 50 , 0.1)]
    return 1
}


ctx::manager register hm OverlapSeamCtx "::HmToolkit::OverlapSeamCtx"
puts "register: HmToolkit::OverlapSeamCtx"