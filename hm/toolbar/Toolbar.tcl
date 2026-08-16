namespace eval ::HmToolkit::Toolbar {
    proc save_file {} {
        set current_file [hm_info currentfile]

        if {$current_file eq ""} {
            set savefile [tk_getSaveFile \
                -title "Save Model As" \
                -defaultextension ".hm" \
                -filetypes {{"HyperMesh binary files" "*.hm"}}]

            if {$savefile eq ""} { return 1 }

            *writefile [file normalize $savefile] 1
            hm_usermessage "Model is saved to $savefile"
            return 1
        } else {
            set folder [file dirname $current_file]
            # 去掉扩展名取基名；若基名末尾已带时间戳 YYMMDD-HHMMSS 则先去除
            set base [file rootname [file tail $current_file]]
            if {[regexp {^(.+)-[0-9]{6}-[0-9]{6}$} $base -> prefix]} {
                set base $prefix
            }
            set timestamp [clock format [clock seconds] -format %y%m%d-%H%M%S]
            set savename "${base}-$timestamp"
            set fullpath [file join $folder "${savename}.hm"]
        }

        hm_answernext yes
        *writefile $fullpath 1
        hm_usermessage "Model is saved to $fullpath"

        return 1
    }

    proc similar {} {
        set tool [::hm::context::GetSelectionTool]
        set type [$tool GetSelectionType]
        if {$type ne "surfs" && $type ne "solids"} {return 1}
        set selected_entities  [$tool GetSelectionIds]
        if {[llength $selected_entities] == 0} {return 1}
        set similar_entities {}

        switch $type {
            surfs {
                *createmark surfs 1 displayed
                set displayed_entities [hm_getmark surfs 1]
                set tolerance 0.05
                # 收集所有选中参考面的特征：(area edges loops)
                set ref_features {}
                foreach ref_id $selected_entities {
                    set ref_area  [hm_getareaofsurface surfs $ref_id]
                    if {$ref_area <= 0} {continue}
                    set ref_loops [hm_getsurfaceedges $ref_id]
                    lappend ref_features \
                        [list $ref_area \
                              [llength [concat {*}$ref_loops]] \
                              [llength $ref_loops]]
                }
                if {[llength $ref_features] == 0} {return 1}

                # 面积粗筛边界（所有参考面的容差并集）
                set area_min [expr {[lindex [lindex $ref_features 0] 0] * (1 - $tolerance)}]
                set area_max [expr {[lindex [lindex $ref_features 0] 0] * (1 + $tolerance)}]
                foreach feat $ref_features {
                    set ra  [lindex $feat 0]
                    set lo [expr {$ra * (1 - $tolerance)}]
                    set hi [expr {$ra * (1 + $tolerance)}]
                    if {$lo < $area_min} {set area_min $lo}
                    if {$hi > $area_max} {set area_max $hi}
                }

                # 批量粗筛：两次 C 层调用（面积≤上限 ∖ 面积<下限）得到候选集，
                # 避免对每个显示面逐次调用 hm_getareaofsurface。
                # 下限取极小负偏移，防止容差边界上的面被误删（精确容差仍在下方判断）。
                set cand_set [dict create]
                foreach id [hm_getsurfacesbyarea $area_max] {dict set cand_set $id 1}
                set lo_val [expr {$area_min * (1 - 1.0e-9)}]
                foreach id [hm_getsurfacesbyarea $lo_val] {dict unset cand_set $id}

                foreach sid $displayed_entities {
                    if {![dict exists $cand_set $sid]} {continue}

                    set a [hm_getareaofsurface surfs $sid]
                    set loops [hm_getsurfaceedges $sid]
                    set e [llength [concat {*}$loops]]
                    set lc [llength $loops]

                    # 与任一参考面匹配即加入结果
                    foreach feat $ref_features {
                        lassign $feat ra re rl
                        if {$re == $e && $rl == $lc && [expr {abs($a - $ra) / $ra}] <= $tolerance} {
                            lappend similar_entities $sid
                            break
                        }
                    }
                }
            }
            solids {
                set tolerance 0.05
                *createmark solids 1 displayed
                set displayed_entities [hm_getmark solids 1]

                # 收集所有选中参考实体的特征：(volume area)（总表面积 = 各边界面面积之和）
                set ref_features {}
                foreach ref_id $selected_entities {
                    set ref_vol [hm_getvolumeofsolid solids $ref_id]
                    if {$ref_vol <= 0} {continue}
                    set ref_area 0
                    foreach sfid [hm_getsurfacesfromsolid $ref_id bounding] {
                        set ref_area [expr {$ref_area + [hm_getareaofsurface surfs $sfid]}]
                    }
                    lappend ref_features [list $ref_vol $ref_area]
                }
                if {[llength $ref_features] == 0} {return 1}

                # 体积粗筛边界（所有参考实体的容差并集）
                set vol_min [expr {[lindex [lindex $ref_features 0] 0] * (1 - $tolerance)}]
                set vol_max [expr {[lindex [lindex $ref_features 0] 0] * (1 + $tolerance)}]
                foreach feat $ref_features {
                    set rv  [lindex $feat 0]
                    set lo [expr {$rv * (1 - $tolerance)}]
                    set hi [expr {$rv * (1 + $tolerance)}]
                    if {$lo < $vol_min} {set vol_min $lo}
                    if {$hi > $vol_max} {set vol_max $hi}
                }

                foreach sid $displayed_entities {
                    set v [hm_getvolumeofsolid solids $sid]
                    if {$v < $vol_min || $v > $vol_max} {continue}

                    # 总表面积 = 各边界面面积之和
                    set area 0
                    foreach sfid [hm_getsurfacesfromsolid $sid bounding] {
                        set area [expr {$area + [hm_getareaofsurface surfs $sfid]}]
                    }

                    # 与任一参考实体匹配（体积容差 + 总表面积容差）
                    foreach feat $ref_features {
                        lassign $feat rv ra
                        if {[expr {abs($v - $rv) / $rv > $tolerance}]} {continue}
                        if {$ra > 0 && [expr {abs($area - $ra) / $ra}] <= $tolerance} {
                            lappend similar_entities $sid
                            break
                        }
                    }
                }
            }
            default {return 1}
        }

        $tool ClearSelection
        $tool SelectByAdvanced "by id only" $similar_entities
    }
}