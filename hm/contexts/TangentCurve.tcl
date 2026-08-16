if {[itcl::is class ::HmToolkit::TangentCurveCtx]} { itcl::delete class ::HmToolkit::TangentCurveCtx}

itcl::class ::HmToolkit::TangentCurveCtx {
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

itcl::body ::HmToolkit::TangentCurveCtx::constructor {args} {
    eval itk_initialize $args
}

itcl::body ::HmToolkit::TangentCurveCtx::proceed {args} {
    if {![ctx::selection count LineSelector1] || ![ctx::selection count LineSelector2]} {return 0}
    if {![ctx::selection count SurfSelector] && ![lindex $args 0]} {return 0}
    ctx StartRecordHistory "Create Tangent Curve"
    if {[catch {__perform} error_info]} {
        ctx EndRecordHistory "Create Tangent Curve"
        ctx Undo
        ctx::selection clear LineSelector1
        ctx::selection clear LineSelector2
        ctx::selection clear SurfSelector
        ctx SetActiveSelection SurfSelector
        Message "Function failed for unknown reason!\nerror info:$error_info"
        return 0
    } else {
        ctx EndRecordHistory "Create Tangent Curve"
        ctx::selection clear LineSelector1
        ctx::selection clear LineSelector2
        ctx::selection clear SurfSelector
        ctx SetActiveSelection SurfSelector
        return 1
    }
}

itcl::body ::HmToolkit::TangentCurveCtx::ok {args} {
    if {[proceed 1]} {ctx::manager exit}
}

itcl::body ::HmToolkit::TangentCurveCtx::cancel {args} {
    ctx::manager exit
}

itcl::body ::HmToolkit::TangentCurveCtx::OnPost {args} {

}

itcl::body ::HmToolkit::TangentCurveCtx::OnUnpost {args} {

}

itcl::body ::HmToolkit::TangentCurveCtx::OnSelectionChange {args} {

}

itcl::body ::HmToolkit::TangentCurveCtx::AutoProceed {args} {
    proceed
}

itcl::body ::HmToolkit::TangentCurveCtx::__perform {args} {
    set line1 [ctx::selection ids LineSelector1]
    set line2 [ctx::selection ids LineSelector2]
    set surf [ctx::selection ids SurfSelector]

    set rv [hm_getclosestpointsbetweentwolines $line1 $line2]
    set coord1 [lrange $rv 0 2]
    set coord2 [lrange $rv 3 5]

    set vec1 [lrange [hm_getlinetangentatcoordinate $line1 {*}$coord1] 3 5]
    set vec2 [lrange [hm_getlinetangentatcoordinate $line2 {*}$coord2] 3 5]

    *createpoint {*}$coord1 0
    set point1 [HmToolkit::Support currentids points]
    *createpoint {*}$coord2 0
    set point2 [HmToolkit::Support currentids points]
    
    *createlist points 1 $point1 $point2

    *createvector 1 {*}$vec1
    *createvector 2 {*}$vec2

    *linecreatespline points 1 2 2 1 2
    set tangent_curve [HmToolkit::Support currentids lines]

    HmToolkit::Modify Delete points "$point1 $point2"

    if {![ctx::selection count SurfSelector]} {return 1}

    set project_curce [HmToolkit::Modify project_entities_to_surf lines $tangent_curve $surf Normally]

    set split [ctx GetOption split]

    if {$split} {
        HmToolkit::Modify split_surf_with_lines $surf $project_curce
        HmToolkit::Modify Delete lines $project_curce
    }

}

ctx::manager register hm TangentCurveCtx "::HmToolkit::TangentCurveCtx"
puts "register: HmToolkit::TangentCurveCtx"