if {[itcl::is class ::HmToolkit::CopyMoveCtx]} { itcl::delete class ::HmToolkit::CopyMoveCtx}

itcl::class ::HmToolkit::CopyMoveCtx {
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

itcl::body ::HmToolkit::CopyMoveCtx::proceed {args} {
    if {![ctx::selection count EntitiesSelector] || ![ctx::selection count StartSelector] || ![ctx::selection count EndSelector]} {return 0}
    ctx StartRecordHistory "Copy Move"
    if {[catch {__perform} error_info]} {
        ctx EndRecordHistory "Copy Move"
        ctx Undo
        Message "Function failed for unknown reason!\nerror info:$error_info"
        ctx::selection clear EntitiesSelector
        ctx::selection clear StartSelector
        ctx::selection clear EndSelector
        ctx SetActiveSelection EntitiesSelector
        return 0
    } else {
        ctx EndRecordHistory "Copy Move"
        ctx::selection clear EntitiesSelector
        ctx::selection clear StartSelector
        ctx::selection clear EndSelector
        ctx SetActiveSelection EndSelector
        return 1
    }
}

itcl::body ::HmToolkit::CopyMoveCtx::ok {args} {
    if {[proceed]} {ctx::manager exit}
}

itcl::body ::HmToolkit::CopyMoveCtx::cancel {args} {
    ctx::manager exit
}

itcl::body ::HmToolkit::CopyMoveCtx::OnPost {args} {
    # 新逻辑由"终点数量"驱动，无 distance/count 选项需要复位
}

itcl::body ::HmToolkit::CopyMoveCtx::OnUnpost {args} {

}

itcl::body ::HmToolkit::CopyMoveCtx::OnSelectionChange {args} {
    # 新逻辑无需根据起终点距离刷新任何选项，保持空实现
}

itcl::body ::HmToolkit::CopyMoveCtx::AutoProceed {args} {
    proceed
}

itcl::body ::HmToolkit::CopyMoveCtx::__perform {args} {
    set ids [ctx::selection ids EntitiesSelector]
    set type [ctx::selection get EntitiesSelector -type]

    set start_sel [ctx GetNamedHMSelection "StartSelector"]
    set start_coord [lindex [lindex [$start_sel GetLocations] 0] 0]

    # 终点多选：GetLocations 返回坐标三元组列表 { {x y z} ... }，每个元素即坐标
    set end_sel [ctx GetNamedHMSelection "EndSelector"]
    set end_coords [lindex [$end_sel GetLocations] 0]
    
    # 每个终点：复制一份原始实体，并沿 start -> endpoint 方向整体平移到该终点
    set new_ids {}
    foreach end_coord $end_coords {
        set vector [HmToolkit::Support Vector sub $end_coord $start_coord]
        set dist [HmToolkit::Query get_dist $start_coord $end_coord]
        if {$dist < 1e-6} {continue}   ;# 跳过与起点重合的终点

        set copies [HmToolkit::Modify Duplicate $type $ids 1]
        if {![llength $copies]} {continue}

        # 归一化方向向量 + 实际距离：在 *translatemark 的两种语义下都正确
        HmToolkit::Modify move $type $copies [HmToolkit::Support Vector normalize $vector] $dist
        lappend new_ids {*}$copies
    }
    return [llength $new_ids]
}

ctx::manager register hm CopyMoveCtx "::HmToolkit::CopyMoveCtx"
puts "register: HmToolkit::CopyMoveCtx"
