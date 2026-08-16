if {[itcl::is class ::HmToolkit::CreateMassPointCtx]} { itcl::delete class ::HmToolkit::CreateMassPointCtx}

itcl::class ::HmToolkit::CreateMassPointCtx {
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

itcl::body ::HmToolkit::CreateMassPointCtx::proceed {args} {
    if {![ctx::selection count SolidsSelector]} {return 0}
    ctx StartRecordHistory "Create Mass Point"
    if {[catch {__perform} error_info]} {
        ctx EndRecordHistory "Create Mass Point"
        ctx Undo
        ctx::selection clear SolidsSelector
        Message "Function failed for unknown reason!\nerror info:$error_info"
        return 0
    } else {
        ctx EndRecordHistory "Create Mass Point"
        ctx::selection clear SolidsSelector
        return 1
    }
}

itcl::body ::HmToolkit::CreateMassPointCtx::ok {args} {
    if{[proceed]} {ctx::manager exit}
}

itcl::body ::HmToolkit::CreateMassPointCtx::cancel {args} {
    ctx::manager exit
}

itcl::body ::HmToolkit::CreateMassPointCtx::OnPost {args} {
    ctx SetOption density 7.85e-9
    ctx SetOption one 0
}

itcl::body ::HmToolkit::CreateMassPointCtx::OnUnpost {args} {

}

itcl::body ::HmToolkit::CreateMassPointCtx::OnSelectionChange {args} {
    if {[ctx::selection count SolidsSelector]} {
        if {![ctx::ui get dialog visible]} {ctx::ui post dialog}
    } else {ctx::ui unpost dialog}
}

itcl::body ::HmToolkit::CreateMassPointCtx::AutoProceed {args} {
    proceed
}

itcl::body ::HmToolkit::CreateMassPointCtx::__perform {args} {
    set density [ctx GetOption density]
    set solids [ctx::selection ids SolidsSelector]
    set one_flag [ctx GetOption one]
    set tag_flag [ctx GetOption tag]
    set move_flag [ctx GetOption move]

    set comp_name "MassPoints"
    if {![set comp [HmToolkit::Query exist comps name=$comp_name]]} {set comp [HmToolkit::Modify Create comps $comp_name]}
    *currentcollector comps $comp_name

    if {$one_flag} {
        set total_mass 0
        set cx 0
        set cy 0
        set cz 0
        foreach solid $solids {
            set volume [hm_getvolumeofsolid solids $solid]
            set mass [expr $volume * $density]
            set total_mass [expr $total_mass + $mass]

            *createmark solids 1 $solid
            set centroid [hm_getcentroid solids 1]

            set sx [lindex $centroid 0]
            set sy [lindex $centroid 1]
            set sz [lindex $centroid 2]

            set cx [expr $cx + $mass * $sx]
            set cy [expr $cy + $mass * $sy]
            set cz [expr $cz + $mass * $sz]
        }

        set cx [expr $cx / $total_mass]
        set cy [expr $cy / $total_mass]
        set cz [expr $cz / $total_mass]

        *createnode $cx $cy $cz
        set node_id [HmToolkit::Support currentids nodes 1]
        *createmark nodes 1 $node_id
        *masselement 1 $total_mass "" 0

        set mass_label [expr round($total_mass * 1000)]
        if {$tag_flag} {*tagcreate nodes $node_id [format "MassPoint_%dKg" $mass_label] "$node_id" 3}
    } else {
        foreach solid $solids {
            set volume [hm_getvalue solids id=$solid dataname=volume]
            set mass [expr $volume * $density]

            *createmark solids 1 $solid
            set centroid [hm_getcentroid solids 1]
            *createnode {*}$centroid
            set node_id [HmToolkit::Support currentids nodes 1]
            *createmark nodes 1 $node_id
            *masselement 1 $mass "" 0

            set mass_label [expr round($mass * 1000)]
            if {$tag_flag} {*tagcreate nodes $node_id [format "MassPoint_%dKg" $mass_label] "$node_id" 3}
        }
    }

    if {$move_flag} {
        *createmark solids 1 {*}$solids
        *movemark solids 1 $comp_name
    }
    *createmark solids 1 {*}$solids
    *maskentitymark solids 1 0

}

ctx::manager register hm CreateMassPointCtx "::HmToolkit::CreateMassPointCtx"
puts "register: HmToolkit::CreateMassPointCtx"