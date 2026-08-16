if {[itcl::is class ::HmToolkit::SmallSolidsCtx]} { itcl::delete class ::HmToolkit::SmallSolidsCtx}

itcl::class ::HmToolkit::SmallSolidsCtx {
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

itcl::body ::HmToolkit::SmallSolidsCtx::proceed {args} {
    if {![ctx::selection count SolidsSelector]} {return 0}
    ctx StartRecordHistory "Small Solids"
    if {[catch {__perform} error_info]} {
        ctx EndRecordHistory "Small Solids"
        ctx Undo
        ctx::selection clear SolidsSelector
        ctx SetActiveSelection SolidsSelector
        Message "Function failed for unknown reason!\nerror info:$error_info"
        return 0
    } else {
        ctx EndRecordHistory "Small Solids"
        ctx::selection clear SolidsSelector
        ctx SetActiveSelection SolidsSelector
        return 1    
    }
}

itcl::body ::HmToolkit::SmallSolidsCtx::ok {args} {
    if {[proceed]} {ctx::manager exit}
}

itcl::body ::HmToolkit::SmallSolidsCtx::cancel {args} {
    ctx::manager exit
}

itcl::body ::HmToolkit::SmallSolidsCtx::OnPost {args} {

}

itcl::body ::HmToolkit::SmallSolidsCtx::OnUnpost {args} {

}

itcl::body ::HmToolkit::SmallSolidsCtx::OnSelectionChange {args} {

}

itcl::body ::HmToolkit::SmallSolidsCtx::AutoProceed {args} {
    proceed
}

itcl::body ::HmToolkit::SmallSolidsCtx::__perform {args} {
    set solids [ctx::selection ids SolidsSelector]
    set sum_volume 0

    if {![set comp [HmToolkit::Query exist comps name=SmallSolids]]} {set comp [HmToolkit::Modify Create comps SmallSolids]}

    set threshold [expr [ctx GetOption threshold] / 100.0] 

    foreach solid $solids {
        set sum_volume [expr $sum_volume + [hm_getvolumeofsolid solids $solid]]
    }

    set average_volume [expr $sum_volume / [llength $solids]]

    set smallsolids {}

    foreach solid $solids {
        if {[hm_getvolumeofsolid solids $solid] < [expr $threshold * $average_volume]} {
            lappend smallsolids $solid
        }
    }

    *createmark solids 1 {*}$smallsolids
    *movemark solids 1 SmallSolids

    return 1
}

ctx::manager register hm SmallSolidsCtx "::HmToolkit::SmallSolidsCtx"
puts "register: HmToolkit::SmallSolidsCtx"