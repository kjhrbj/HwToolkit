if {[itcl::is class ::HmToolkit::BadElementCtx]} { itcl::delete class ::HmToolkit::BadElementCtx}

itcl::class ::HmToolkit::BadElementCtx {
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

itcl::body ::HmToolkit::BadElementCtx::proceed {args} {
    if {![ctx::selection count ElemsSelector]} {return 0}
    ctx StartRecordHistory "Pick up Bad Elements"
    if {[catch {__perform} error_info]} {
        ctx EndRecordHistory "Pick up Bad Elements"
        ctx Undo
        ctx::selection clear ElemsSelector
        ctx SetActiveSelection ElemsSelector
        Message "Function failed for unknown reason!\nerror info:$error_info"
        return 0
    } else {
        ctx EndRecordHistory "Pick up Bad Elements"
        ctx::selection clear ElemsSelector
        ctx SetActiveSelection ElemsSelector
        return 1
    }
}

itcl::body ::HmToolkit::BadElementCtx::ok {args} {
    if {[proceed]} {ctx::manager exit}
}

itcl::body ::HmToolkit::BadElementCtx::cancel {args} {
    ctx::manager exit
}

itcl::body ::HmToolkit::BadElementCtx::OnPost {args} {

}

itcl::body ::HmToolkit::BadElementCtx::OnUnpost {args} {

}

itcl::body ::HmToolkit::BadElementCtx::OnSelectionChange {args} {

}

itcl::body ::HmToolkit::BadElementCtx::AutoProceed {args} {
    proceed
}

itcl::body ::HmToolkit::BadElementCtx::__perform {args} {
    set elems [ctx::selection ids ElemsSelector]
    set adjacent [ctx GetOption adjacent]

    *createmark elems 1 {*}$elems
    hm_getelementsqualityinfo 1 0 2
    set bad_elems [hm_getmark elems 2]

    if {![llength $bad_elems]} {return 0}

    hm_usermessage "Find adjacent elements"
    set bad_elems [HmToolkit::Query adjacent_elems $bad_elems $adjacent]

    if {![set bad_elems_set [HmToolkit::Query exist set name=Bad_Elems]]} {
        *createentity sets cardimage=SET_ELEM includeid=0 name="Bad_Elems"
        set bad_elems_set [HmToolkit::Support currentids set 1]
    }

    *setvalue sets id=$bad_elems_set STATUS=2 ids=$bad_elems
}

ctx::manager register hm BadElementCtx "::HmToolkit::BadElementCtx"
puts "register: HmToolkit::BadElementCtx"