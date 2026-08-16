if {[itcl::is class ::HmToolkit::ProjectionToSurfCtx]} { itcl::delete class ::HmToolkit::ProjectionToSurfCtx}

itcl::class ::HmToolkit::ProjectionToSurfCtx {
    inherit ::hm::context::HMScriptableBase
    constructor {args} {}

    public method proceed {args}
    public method ok {args}
    public method cancel {args}

    public method OnPost {args}
    public method OnUnpost {args}
    public method OnSelectionChange {args}
    public method AutoProceed {args}

    public method set_direction {type}

    private method __perform {args}
    private method __preview {args}

    private method __delete_temp {args}

    private variable direction
    private variable temp
    private variable temp_type
    private variable temp_comp
}

itcl::body ::HmToolkit::ProjectionToSurfCtx::proceed {args} {
    if {![ctx::selection count SurfSelector] || ![ctx::selection count EntitiesSelector]} {return 0}
    if {($direction eq "Direction") && ![ctx::selection count DirectSelector]} {return 0}
    ctx StartRecordHistory "Projection Confirm"
    if {[catch {__perform} error_info]} {
        ctx EndRecordHistory "Projection Confirm"
        ctx Undo
        Message "Function failed for unknown reason!\nerror info:$error_info"

        ctx::selection clear SurfSelector
        ctx::selection clear EntitiesSelector
        ctx::selection clear DirectSelector

        return 0
    } else {
        __delete_temp
        ctx EndRecordHistory "Projection Confirm"

        ctx::selection clear SurfSelector
        ctx::selection clear EntitiesSelector
        ctx::selection clear DirectSelector

        ctx SetActiveSelection EntitiesSelector
    }
    return 1
}

itcl::body ::HmToolkit::ProjectionToSurfCtx::ok {args} {
    if {[proceed]} {ctx::manager exit}
}

itcl::body ::HmToolkit::ProjectionToSurfCtx::cancel {args} {
    ctx::manager exit
}

itcl::body ::HmToolkit::ProjectionToSurfCtx::OnPost {args} {
    set direction Normally
    set temp {}
    set temp_type 0

    set temp_comp [HmToolkit::Modify Create comps ProjectionTemp]
    ctx StartRecordHistory "Create Temp Component"
    *createmark components 1 $temp_comp
    *setvalue comps mark=1 color=#FF0000
    *clearmark components 1
    ctx EndRecordHistory "Create Temp Component"
}

itcl::body ::HmToolkit::ProjectionToSurfCtx::OnUnpost {args} {
    ctx StartRecordHistory "Delete Temp Data"
    if {[llength $temp]} {__delete_temp}
    *createmark comps 1 $temp_comp
    *deletemark comps 1
    ctx EndRecordHistory "Delete Temp Data"
}

itcl::body ::HmToolkit::ProjectionToSurfCtx::OnSelectionChange {args} {

    if {![ctx::selection count SurfSelector] || ![ctx::selection count EntitiesSelector]} {return 0}
    if {($direction eq "Direction") && ![ctx::selection count DirectSelector]} {return 0}

    ctx StartRecordHistory "Projection Preview"
    __delete_temp
    if {[catch {__preview} error_info]} {
        ctx EndRecordHistory "Projection Preview"
        ctx Undo
        Message "Fail in preview process!\nError info:$error_info"
    }
    ctx EndRecordHistory "Projection Preview"
}

itcl::body ::HmToolkit::ProjectionToSurfCtx::AutoProceed {args} {
    if {![proceed]} {return}
    if {$direction eq "Normally"} {ctx SetActiveSelection SurfSelector} else {ctx SetActiveSelection DirectSelector}
}

itcl::body ::HmToolkit::ProjectionToSurfCtx::set_direction {type} {
    ctx::ui set dir_chooser -label $type
    switch $type {
        Normally {
            ctx::ui set seldirec -visible 0
            ctx::ui set preview -visible 0
            ctx::selection clear DirectSelector
            set direction Normally
        }
        Direction {
            ctx::ui set seldirec -visible 1
            ctx::ui set preview -visible 1
            set direction Direction
        }
        default {}
    }
}

itcl::body ::HmToolkit::ProjectionToSurfCtx::__perform {args} {
    set surf [ctx::selection ids SurfSelector]

    set entities_type [ctx::selection get EntitiesSelector -type]

    if {$entities_type eq "lines"} {HmToolkit::Modify split_surf_with_lines $surf $temp}

    if {$entities_type eq "points"} {
        HmToolkit::Modify add_points_on_surface $surf $temp
    }
    set temp {}
    return 1
}

itcl::body ::HmToolkit::ProjectionToSurfCtx::__preview {args} {
    set surf [ctx::selection ids SurfSelector]

    set entities_type [ctx::selection get EntitiesSelector -type]

    set entities [ctx::selection ids EntitiesSelector]

    if {$entities_type in "lines points"} {set entities [HmToolkit::Modify Duplicate $entities_type $entities]}

    if {$direction eq "Direction"} {
        if {[ctx::selection get DirectSelector -type] eq "Vector"} {
            set vecid [ctx::selection ids DirectSelector]
            set vec "[hm_getvalue vector id=$vecid dataname=xcomp] [hm_getvalue vector id=$vecid dataname=ycomp] [hm_getvalue vector id=$vecid dataname=zcomp]"
        } else {
            set dir [[ctx GetNamedHMSelection "DirectSelector"] GetPlaneBaseandAxis]
            set vec [lrange $dir 3 5]
        }
    } else {set vec Normally}

    set temp [HmToolkit::Modify project_entities_to_surf $entities_type $entities $surf $vec]

    set temp_type $entities_type
}

itcl::body ::HmToolkit::ProjectionToSurfCtx::__delete_temp {args} {
    if {![llength $temp]} {return 0}
    HmToolkit::Modify Delete $temp_type $temp
    set temp {}
}

ctx::manager register hm ProjectionToSurfCtx "::HmToolkit::ProjectionToSurfCtx"
puts "register: HmToolkit::ProjectionToSurfCtx"