namespace eval HvToolkit::HvApi {
    namespace export *

    # 将激活 HyperView 窗口截图保存为 PNG 到当前工作目录。
    # 参考官方 demo 的 CaptureHVWindowToJPEGFileFixedNamResolution。
    # 返回保存的完整路径；失败返回空串。
    proc get_contour_value {selectionset_id contour_type {subcase "all"} {simulaiton "all"}} {
        hwi OpenStack
        set t [expr rand()][clock milliseconds]

        # 句柄链：client -> model -> result ctrl
        hwi GetActiveClientHandle cl$t

        if {[cl$t GetModelHandle m$t [cl$t GetActiveModel mid]] ne "m$t"} {
            hwi CloseStack
            return -code error "Failed to get model handle"
        }
        if {[m$t GetSelectionSetHandle sel$t $selectionset_id] ne "sel$t"} {
            hwi CloseStack
            return -code error "Failed to get selectionset handle"
        }
        set entity_type [sel$t GetType]

        if {[m$t GetResultCtrlHandle rc$t] ne "rc$t"} {
            hwi CloseStack
            return -code error "Failed to get result control handle"
        }

        # 这里后续加一个校验，检查rc$t GetDataTypeList中是否有要查询的contour type

        if {[rc$t GetContourCtrlHandle cc$t] ne "cc$t"} {
            hwi CloseStack
            return -code error "Failed to get contour control handle"
        }

        switch $contour_type {
            Displacement {
                if {$entity_type ne "node"} {
                    hwi CloseStack
                    return -code error "Inconsistent query entity type:$entity_type and contour type:$contour_type"
                }
                cc$t SetDataType Displacement
                cc$t SetEnableState true
            }
            "Element Stresses (2D & 3D)" {
                if {$entity_type eq "node"} {
                    cc$t SetDataType "Element Stresses (2D & 3D)"
                    cc$t SetDataComponent vonMises
                    cc$t SetAverageMode simple
                    cc$t SetAvgAcrossPartsEnable true
                    cc$t SetEnableState true
                } elseif {$entity_type eq "element"} {
                    cc$t SetDataType "Element Stresses (2D & 3D)"
                    cc$t SetDataComponent vonMises
                    cc$t SetAverageMode none
                    cc$t SetEnableState true 
                } else {
                    hwi CloseStack
                    return -code error "Inconsistent query entity type:$entity_type and contour type:$contour_type"
                }
            }
            default {
                hwi CloseStack
                return -code error "Unsupport query type:$contour_type"
            }
        }

        # 查询控制：Displacement
        if {[m$t GetQueryCtrlHandle qc$t] ne "qc$t"} {
            hwi CloseStack
            return -code error "Failed to get query control handle"
        }
        qc$t SetSelectionSet [sel$t GetID]
        qc$t SetQuery "$entity_type.id contour.value"

        # 遍历 subcase（分析步） -> simulation（时间步）
        set result {}
        if {$subcase eq "all"} {
            foreach sc [rc$t GetSubcaseList] {
                rc$t SetCurrentSubcase $sc
                set current_sc_res {}
                if {$simulaiton eq "all"} {
                    set nsim [rc$t GetNumberOfSimulations $sc]
                    for {set si 0} {$si < $nsim} {incr si} {
                        rc$t SetCurrentSimulation $si

                        set data [__qc_get_datalist qc$t]
                        dict lappend current_sc_res $si {*}$data
                    }
                } else {
                    set si $simulation
                    rc$t SetCurrentSimulation $si
                    set data [__qc_get_datalist qc$t]
                    dict lappend current_sc_res $si $data
                }
                dict lappend result $sc {*}$current_sc_res
            }
        } else {
            set sc $subcase
            rc$t SetCurrentSubcase $sc
            set current_sc_res {}
            if {$simulaiton eq "all"} {
                    set nsim [rc$t GetNumberOfSimulations $subcase]
                    for {set si 0} {$si < $nsim} {incr si} {
                        rc$t SetCurrentSimulation $si

                        set data [__qc_get_datalist qc$t]
                        dict lappend current_sc_res $si {*}$data
                    }
            } else {
                    set si $simulation
                    rc$t SetCurrentSimulation $si
                    set data [__qc_get_datalist qc$t]
                    dict lappend current_sc_res $si {*}$data
            }
            dict lappend result $sc {*}$current_sc_res
        }

        hwi CloseStack

        return $result
    }

    proc __qc_get_datalist {qc} {
        if {[$qc GetIteratorHandle __it] ne "__it"} {
            hwi CloseStack
            return -code error "Failed to get iterator handle"
        }
        set result {}
        for {__it First} {[__it Valid]} {__it Next} {
            set data [concat {*}[__it GetDataList]]
            lappend result {*}$data
        }
        __it ReleaseHandle

        return $result
    }

    proc info_selectionset {selset_id} {
        hwi OpenStack
        set t [expr rand()][clock milliseconds]

        # 句柄链：client -> model -> result ctrl
        hwi GetActiveClientHandle cl$t

        if {[cl$t GetModelHandle m$t [cl$t GetActiveModel mid]] ne "m$t"} {
            hwi CloseStack
            return -code error "Failed to get model handle"
        }
        if {[m$t GetSelectionSetHandle sel$t $selset_id] ne "sel$t"} {
            hwi CloseStack
            return -code error "Failed to get selectionset handle"
        }

        set info {}

        dict set info label [sel$t GetLabel]
        dict set info type [sel$t GetType]
        dict set info size [sel$t GetSize]

        hwi CloseStack

        return $info
    }

    proc get_subcase_label {sc} {
        hwi OpenStack
        set t [expr rand()][clock milliseconds]

        hwi GetActiveClientHandle cl$t

        if {[cl$t GetModelHandle m$t [cl$t GetActiveModel mid]] ne "m$t"} {
            hwi CloseStack
            return -code error "Failed to get model handle"
        }
        if {[m$t GetResultCtrlHandle rc$t] ne "rc$t"} {
            hwi CloseStack
            return -code error "Failed to get result control handle"
        }

        set label [rc$t GetSubcaseLabel $sc]
        if {[llength $label] eq 3} {set label [lindex $label 2]}
        hwi CloseStack

        return $label
    }

    proc get_subcase_list {} {
        hwi OpenStack
        set t [expr rand()][clock milliseconds]

        hwi GetActiveClientHandle cl$t

        if {[cl$t GetModelHandle m$t [cl$t GetActiveModel mid]] ne "m$t"} {
            hwi CloseStack
            return -code error "Failed to get model handle"
        }
        if {[m$t GetResultCtrlHandle rc$t] ne "rc$t"} {
            hwi CloseStack
            return -code error "Failed to get result control handle"
        }

        set sc_list [rc$t GetSubcaseList]
        hwi CloseStack
        return $sc_list
    }

    proc get_simulation_label {sc index} {
        hwi OpenStack
        set t [expr rand()][clock milliseconds]

        hwi GetActiveClientHandle cl$t

        if {[cl$t GetModelHandle m$t [cl$t GetActiveModel mid]] ne "m$t"} {
            hwi CloseStack
            return -code error "Failed to get model handle"
        }
        if {[m$t GetResultCtrlHandle rc$t] ne "rc$t"} {
            hwi CloseStack
            return -code error "Failed to get result control handle"
        }

        set label [rc$t GetSimulationLabel $sc $index]
        hwi CloseStack

        return $label
    }

    proc get_model_filename {} {
        hwi OpenStack
        set t [expr rand()][clock milliseconds]

        hwi GetActiveClientHandle cl$t

        if {[cl$t GetModelHandle m$t [cl$t GetActiveModel mid]] ne "m$t"} {
            hwi CloseStack
            return -code error "Failed to get model handle"
        }

        set filename [m$t GetFileName]

        hwi CloseStack

        return $filename
    }

    # 获取当前工作目录；失败返回空串。
    proc get_current_working_dir {} {
        set t [expr rand()][clock milliseconds]
        hwi GetSessionHandle sesh$t
        if {[catch {sesh$t GetSystemVariable CURRENTWORKINGDIR} dir]} {
            sesh$t ReleaseHandle
            return ""
        }
        sesh$t ReleaseHandle
        return $dir
    }

}