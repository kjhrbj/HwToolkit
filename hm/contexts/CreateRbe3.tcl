if {[itcl::is class ::HmToolkit::CreateRbe3Ctx]} { itcl::delete class ::HmToolkit::CreateRbe3Ctx}

itcl::class ::HmToolkit::CreateRbe3Ctx {
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

itcl::body ::HmToolkit::CreateRbe3Ctx::proceed {args} {
    if {![ctx::selection count ElemsSelector]} {return 0}
    ctx StartRecordHistory "Create Rbe3"
    if {[catch {__perform} error_info]} {
        ctx EndRecordHistory "Create Rbe3"
        ctx Undo
        ctx::selection clear ElemsSelector
        ctx SetActiveSelection ElemsSelector
        Message "Function failed for unknown reason!\nerror info:$error_info"
        return 0
    } else {
        ctx EndRecordHistory "Create Rbe3"
        ctx::selection clear ElemsSelector
        ctx SetActiveSelection ElemsSelector
        return 1
    }

}

itcl::body ::HmToolkit::CreateRbe3Ctx::ok {args} {
    if {[proceed]} {ctx::manager exit}
}

itcl::body ::HmToolkit::CreateRbe3Ctx::cancel {args} {
    ctx::manager exit
}

itcl::body ::HmToolkit::CreateRbe3Ctx::OnPost {args} {

}

itcl::body ::HmToolkit::CreateRbe3Ctx::OnUnpost {args} {

}

itcl::body ::HmToolkit::CreateRbe3Ctx::OnSelectionChange {args} {

}

itcl::body ::HmToolkit::CreateRbe3Ctx::AutoProceed {args} {
    proceed
}

itcl::body ::HmToolkit::CreateRbe3Ctx::__perform {args} {
    set elems [ctx::selection ids ElemsSelector]
    set main_node 0

    set nodes {}

    foreach elem $elems {
        if {[hm_getvalue elems id=$elem dataname=config] == 55} {
            lappend nodes [hm_getvalue elems id=$elem dataname=independentnode]
            continue
        } elseif {[hm_getvalue elems id=$elem dataname=config] == 1} {
            if {$main_node} {
                Message "Selected more than one mass elements, function fail!"
                return 1
            }
            set main_node [hm_getvalue elems id=$elem dataname=nodes]
        }
        lappend nodes {*}[hm_getvalue elems id=$elem dataname=nodes]
    }
    if {[llength $nodes] <= 1} {
        Message "Selected nodes less than 1, it is unnecessary to create Rbe3"
        return 0
    }
    HmToolkit::Support lunique nodes

    set comp_name [ctx GetOption name]
    if {![set comp [HmToolkit::Query exist comps name=$comp_name]]} {set comp [HmToolkit::Modify Create comps $comp_name]}
    *currentcollector comp $comp_name

    HmToolkit::Support lremove nodes $main_node
    set auto_weight [ctx GetOption auto_weight]
    HmToolkit::Modify Create Rbe3 $nodes $main_node 123456 $auto_weight
    hm_usermessage "Rbe3 created successfully."

    return 1
}

ctx::manager register hm CreateRbe3Ctx "::HmToolkit::CreateRbe3Ctx"
puts "register: HmToolkit::CreateRbe3Ctx"