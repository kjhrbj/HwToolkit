if {[itcl::is class ::HmToolkit::ThicknessAssignCtx]} {itcl::delete class ::HmToolkit::ThicknessAssignCtx}

itcl::class ::HmToolkit::ThicknessAssignCtx {
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

itcl::body ::HmToolkit::ThicknessAssignCtx::proceed {args} {
    if {![ctx::selection count SurfsSelector]} {return 0}
    ctx StartRecordHistory "Thickness Assign"
    if {[catch {__perform} error_info]} {
        ctx EndRecordHistory "Thickness Assign"
        ctx Undo
        ctx::selection clear SurfsSelector
        ctx SetActiveSelection SurfsSelector
        Message "Function failed for unknown reason!\nerror info:$error_info"
        return 0
    } else {
        ctx EndRecordHistory "Thickness Assign"
        ctx::selection clear SurfsSelector
        ctx SetActiveSelection SurfsSelector
        return 1
    }
}

itcl::body ::HmToolkit::ThicknessAssignCtx::ok {args} {
    if {[proceed]} {ctx::manager exit}
}

itcl::body ::HmToolkit::ThicknessAssignCtx::cancel {args} {
    ctx::manager exit
}

itcl::body ::HmToolkit::ThicknessAssignCtx::OnPost {args} {

}

itcl::body ::HmToolkit::ThicknessAssignCtx::OnUnpost {args} {

}

itcl::body ::HmToolkit::ThicknessAssignCtx::OnSelectionChange {args} {

}

itcl::body ::HmToolkit::ThicknessAssignCtx::AutoProceed {args} {
    proceed
}

itcl::body ::HmToolkit::ThicknessAssignCtx::__perform {args} {
    set surfs [ctx::selection ids SurfsSelector]
    set increment [ctx GetOption increment]
    set max_thickness [ctx GetOption max_thickness]
    set prefix [ctx GetOption prefix]
    if {$prefix eq ""} {set prefix "Surfaces"}

    set surf_dict {}
    foreach surf $surfs {
        set thickness [HmToolkit::Query get_thickness_surf $surf]
        set n [expr round($thickness / $increment)]
        dict lappend surf_dict $n $surf
    }
    foreach {n d_surfs} $surf_dict {
        set thickness [expr $n * $increment]
        if {$thickness > $max_thickness} {
            set comp_name "${prefix}-ExceedMaxThickness"
            if {![set comp [HmToolkit::Query exist comps name=$comp_name]]} {set comp [HmToolkit::Modify Create comps $comp_name]}
            *createmark surfs 1 {*}$d_surfs
            *movemark surfs 1 $comp_name
        } elseif {$thickness <= 0} {
            set comp_name "${prefix}-NoneThickness"
            if {![set comp [HmToolkit::Query exist comps name=$comp_name]]} {set comp [HmToolkit::Modify Create comps $comp_name]}
            *createmark surfs 1 {*}$d_surfs
            *movemark surfs 1 $comp_name
        } else {
            set comp_name "${prefix}-T$thickness"
            if {![set comp [HmToolkit::Query exist comps name=$comp_name]]} {set comp [HmToolkit::Modify Create comps $comp_name]}

            set mat [HmToolkit::Modify Create material Steel -E 210000 -G 80769.2 -NU 0.3 -RHO 7.85e-09]
            set prop [HmToolkit::Modify Create shell_property Shell-Steel-T$thickness $thickness $mat]
            *setvalue comps id=$comp propertyid=$prop

            *createmark surfs 1 {*}$d_surfs
            *movemark surfs 1 $comp_name
        }
    }
    return 1
}

ctx::manager register hm ThicknessAssignCtx "::HmToolkit::ThicknessAssignCtx"
puts "register: HmToolkit::ThicknessAssignCtx"