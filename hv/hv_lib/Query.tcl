# HvToolkit HyperView 查询库：封装 hwi 查询类 API（参考官方 demo：hwdesktop/demos/sdk/extensions/Extension_Demo/hv/hv-init.tcl）
# 通用 handle 调用链：
#   hwi GetActiveClientHandle cl$t  ->  cl$t GetActiveModel / GetModelHandle ...
# 用完的 handle 必须 ReleaseHandle。
namespace eval HvToolkit::Query {

    namespace export *

    # 获取当前激活模型 ID。
    # 返回模型 ID；当前无激活模型返回 0。
    proc active_model_id {} {
        set t [expr rand()][clock milliseconds]
        # HyperView 命令失败返回非零错误码而非抛异常，需检查返回值（catch 无效）
        if {[hwi GetActiveClientHandle cl$t] != 0} {
            return 0
        }
        set mid [cl$t GetActiveModel]
        cl$t ReleaseHandle
        return $mid
    }

    # 获取当前激活模型的标签（Label）。
    # 返回标签字符串；无激活模型返回空串。
    proc active_model_label {} {
        set t [expr rand()][clock milliseconds]
        # HyperView 命令失败返回非零错误码而非抛异常，需检查返回值（catch 无效）
        if {[hwi GetActiveClientHandle cl$t] != 0} {
            return ""
        }
        set mid [cl$t GetActiveModel]
        if {$mid == 0 || [cl$t GetModelHandle m$t $mid] != 0} {
            cl$t ReleaseHandle
            return ""
        }
        set label [m$t GetLabel]
        m$t ReleaseHandle
        cl$t ReleaseHandle
        return $label
    }

    # 获取当前激活模型文件名。
    # 返回文件名；无激活模型返回空串。
    proc active_model_filename {} {
        set t [expr rand()][clock milliseconds]
        # HyperView 命令失败返回非零错误码而非抛异常，需检查返回值（catch 无效）
        if {[hwi GetActiveClientHandle cl$t] != 0} {
            return ""
        }
        set mid [cl$t GetActiveModel]
        if {$mid == 0 || [cl$t GetModelHandle m$t $mid] != 0} {
            cl$t ReleaseHandle
            return ""
        }
        set fname [m$t GetFileName]
        m$t ReleaseHandle
        cl$t ReleaseHandle
        return $fname
    }

    proc get_node_displacement {nodes subcase sim} {
        hwi OpenStack

        # 句柄链：client -> model -> result ctrl
        # 注意：HyperView 命令失败返回非零错误码而非抛异常，需检查返回值（catch 无效）
        if {[hwi GetActiveClientHandle cl] != "cl"} {
            hwi CloseStack
            return -code error "No active client!"
        }

        set mid [cl GetActiveModel]
        if {[cl GetModelHandle m $mid] != "m"} {
            hwi CloseStack
            return -code error "Failed to get model handle!"
        }
        if {[m GetResultCtrlHandle rc] != "rc"} {
            hwi CloseStack
            return -code error "Failed to get result ctrl handle!"
        }

        # 节点选择集：只包含该节点
        set sid [m AddSelectionSet node]
        if {[m GetSelectionSetHandle sel $sid] != "sel"} {
            hwi CloseStack
            return -code error "Failed to create node selection set!"
        }
        if {[sel Add "id == $nodes"] != 0} {
            hwi CloseStack
            return -code error "Failed to add node to selection set!"
        }

        # 查询控制：Displacement
        if {[m GetQueryCtrlHandle qc] != "qc"} {
            hwi CloseStack
            return -code error "Failed to get query ctrl handle!"
        }
        if {[qc SetSelectionSet [sel GetID]] != 0} {
            hwi CloseStack
            return -code error "Failed to set query selection set!"
        }
        if {[qc SetDataSourceProperty result datatype Displacement] != 0} {
            hwi CloseStack
            return -code error "Failed to set query datatype Displacement!"
        }
        if {[qc SetQuery "node.id result.value"] != 0} {
            hwi CloseStack
            return -code error "Failed to set query!"
        }

        # 遍历 subcase（分析步） -> simulation（时间步）
        set result_list {}
        set qerr ""
        catch {
            if {$subcase ni [rc GetSubcaseList]} {return -code error "No subcase:$subcase"}
            if {$sim > [rc GetNumberOfSimulations $subcase]} {return -code error "Simulation exceeded"}

            if {[rc SetCurrentSubcase $subcase] != 0} { error "SetCurrentSubcase failed (subcase $subcase)" }
            if {[rc SetCurrentSimulation $sim] != 0} { error "SetCurrentSimulation failed (sim $sim)" }

            set time ""
            if {[rc GetSubcaseHandle sub $subcase] == 0} {
                if {![catch {sub GetSyncValue $sim} tv]} { set time $tv }
                sub ReleaseHandle
            }

            if {[qc GetIteratorHandle it] != "it"} { error "GetIteratorHandle failed" }
            puts [it Valid]
            for {it First} {[it Valid]} {it Next} {
                set data [it GetDataList]
                lappend result_list [list $subcase $sim $time $data]
            }
            it ReleaseHandle
        } qerr

        hwi CloseStack

        if {$qerr ne ""} {
            return -code error "Query failed: $qerr"
        }
        return $result_list
    }
    # 获取指定节点在所有分析步（subcase）、所有时间步（simulation）下的位移（Displacement）值。
    # 原理：poIQueryCtrl 的迭代器是「当前模型 + 当前 simulation」的快照，
    #       因此外层遍历 subcase、内层遍历 simulation，每步 SetCurrentSubcase/
    #       SetCurrentSimulation 后重新取迭代器查询。
    # 返回：列表，每行 {subcase_id sim_index time data}；time 为空表示未取到时间值。
    proc get_node_displacement_1 {node_id} {
        hwi OpenStack
        set t [expr rand()][clock milliseconds]

        # 句柄链：client -> model -> result ctrl
        # 注意：HyperView 命令失败返回非零错误码而非抛异常，需检查返回值（catch 无效）
        if {[hwi GetActiveClientHandle cl$t] != 0} {
            hwi CloseStack
            return -code error "No active client!"
        }
        set mid [cl$t GetActiveModel]
        if {$mid == 0} {
            hwi CloseStack
            return -code error "No active model!"
        }
        if {[cl$t GetModelHandle m$t $mid] != 0} {
            hwi CloseStack
            return -code error "Failed to get model handle!"
        }
        if {[m$t GetResultCtrlHandle rc$t] != 0} {
            hwi CloseStack
            return -code error "Failed to get result ctrl handle!"
        }

        # 节点选择集：只包含该节点
        set sid [m$t AddSelectionSet node]
        if {[m$t GetSelectionSetHandle sel$t $sid] != 0} {
            hwi CloseStack
            return -code error "Failed to create node selection set!"
        }
        if {[sel$t Add "id == $node_id"] != 0} {
            hwi CloseStack
            return -code error "Failed to add node to selection set!"
        }

        # 查询控制：Displacement
        if {[m$t GetQueryCtrlHandle qc$t] != 0} {
            hwi CloseStack
            return -code error "Failed to get query ctrl handle!"
        }
        if {[qc$t SetSelectionSet [sel$t GetID]] != 0} {
            hwi CloseStack
            return -code error "Failed to set query selection set!"
        }
        if {[qc$t SetDataSourceProperty result datatype Displacement] != 0} {
            hwi CloseStack
            return -code error "Failed to set query datatype Displacement!"
        }
        if {[qc$t SetQuery "node.id result.value"] != 0} {
            hwi CloseStack
            return -code error "Failed to set query!"
        }

        # 遍历 subcase（分析步） -> simulation（时间步）
        set result_list {}
        set qerr ""
        catch {
            foreach sc [rc$t GetSubcaseList] {
                set nsim [rc$t GetNumberOfSimulations $sc]
                for {set si 0} {$si < $nsim} {incr si} {
                    if {[rc$t SetCurrentSubcase $sc] != 0} { error "SetCurrentSubcase failed (subcase $sc)" }
                    if {[rc$t SetCurrentSimulation $si] != 0} { error "SetCurrentSimulation failed (sim $si)" }

                    # 可选：该时间步的时间值（subcase GetSyncValue）
                    set time ""
                    if {[rc$t GetSubcaseHandle sub$t $sc] == 0} {
                        if {![catch {sub$t GetSyncValue $si} tv] && [string is double -strict $tv]} { set time $tv }
                        sub$t ReleaseHandle
                    }

                    # 每次重新取迭代器（快照随当前 simulation 变化）
                    if {[qc$t GetIteratorHandle it$t] != 0} { error "GetIteratorHandle failed" }
                    for {it$t First} {[it$t Valid]} {it$t Next} {
                        set data [it$t GetDataList]
                        lappend result_list [list $sc $si $time $data]
                    }
                    it$t ReleaseHandle
                }
            }
        } qerr

        hwi CloseStack

        if {$qerr ne ""} {
            return -code error "Query failed: $qerr"
        }
        return $result_list
    }

    # 获取指定节点在所有分析步（subcase）、所有时间步（simulation）下的应力（Stress）值。
    # 支持多节点：node_ids 可为单个节点 ID、节点 ID 列表、或选择集表达式字符串
    #   （如 "id == 1 or id == 2"）；传 "all" 查询全部节点（注意数据量大）。
    # datatype：结果数据类型标签，默认 "Stress"，可传 "Stress (vM)" 等具体标签。
    # 选项（args，均可选）：
    #   -averaging <mode>   显式控制节点平均模式（none/simple/advanced/difference/
    #                       maximum/minimum/max of corner/min of corner/extreme of corner）。
    #                       查询前设置、查询后恢复原设置；若结果定义已缓存导致设置失败，
    #                       则降级为当前设置并提示。
    #   -fields <query>     查询语句，默认 "node.id result.value"。
    # 原理：与 get_node_displacement 相同——poIQueryCtrl 迭代器是「当前模型 + 当前
    #       simulation」的快照，外层遍历 subcase、内层遍历 simulation。
    # 说明：应力是单元型（element 绑定）结果，节点应力值 = 单元积分点外推并平均到节点的值，
    #       因此受平均模式（-averaging）影响；且节点平均值由「激活的 scalar 结果定义」生成——
    #       需该结果定义配置为此数据类型并加载（LoadResult，需 HyperView - MultiCore profile），
    #       函数会自动设置并恢复。位移等节点绑定结果无需此步。
    # 返回：列表，每行 {subcase_id sim_index time data}；time 为空表示未取到时间值，
    #       data 为 GetDataList，格式如 "node_id value"（或含 -fields 中其它字段）。
    proc get_node_stress {node_ids {datatype "Stress"} args} {
        # 解析可选参数
        set averaging ""
        set fields "node.id result.value"
        for {set i 0} {$i < [llength $args]} {incr i} {
            switch -- [lindex $args $i] {
                -averaging {
                    incr i
                    set averaging [lindex $args $i]
                }
                -fields {
                    incr i
                    set fields [lindex $args $i]
                }
                default {
                    return -code error "Unknown option: [lindex $args $i]"
                }
            }
        }

        hwi OpenStack
        set t [expr rand()][clock milliseconds]

        # 句柄链：client -> model -> result ctrl
        # 注意：HyperView 命令失败返回非零错误码而非抛异常，需检查返回值（catch 无效）
        if {[hwi GetActiveClientHandle cl$t] != 0} {
            hwi CloseStack
            return -code error "No active client!"
        }
        set mid [cl$t GetActiveModel]
        if {$mid == 0} {
            hwi CloseStack
            return -code error "No active model!"
        }
        if {[cl$t GetModelHandle m$t $mid] != 0} {
            hwi CloseStack
            return -code error "Failed to get model handle!"
        }
        if {[m$t GetResultCtrlHandle rc$t] != 0} {
            hwi CloseStack
            return -code error "Failed to get result ctrl handle!"
        }

        # 节点选择集：单 ID / ID 列表 / 表达式 / all
        set sid [m$t AddSelectionSet node]
        if {[m$t GetSelectionSetHandle sel$t $sid] != 0} {
            hwi CloseStack
            return -code error "Failed to create node selection set!"
        }
        if {$node_ids eq "all"} {
            set expr "all"
        } elseif {[llength $node_ids] == 1 && [string is integer -strict $node_ids]} {
            set expr "id == $node_ids"
        } else {
            set is_id_list 1
            foreach n $node_ids {
                if {![string is integer -strict $n]} {
                    set is_id_list 0
                    break
                }
            }
            if {$is_id_list} {
                set parts {}
                foreach n $node_ids { lappend parts "id == $n" }
                set expr [join $parts " or "]
            } else {
                # 非纯整数列表：视为原始选择集表达式
                set expr $node_ids
            }
        }
        if {[sel$t Add $expr] != 0} {
            hwi CloseStack
            return -code error "Failed to add nodes to selection set!"
        }

        # 查询控制：Stress
        if {[m$t GetQueryCtrlHandle qc$t] != 0} {
            hwi CloseStack
            return -code error "Failed to get query ctrl handle!"
        }
        if {[qc$t SetSelectionSet [sel$t GetID]] != 0} {
            hwi CloseStack
            return -code error "Failed to set query selection set!"
        }
        if {[qc$t SetDataSourceProperty result datatype $datatype] != 0} {
            hwi CloseStack
            return -code error "Failed to set query datatype '$datatype'!"
        }
        if {[qc$t SetQuery $fields] != 0} {
            hwi CloseStack
            return -code error "Failed to set query '$fields'!"
        }

        # 节点查询单元型结果（如应力）时，节点平均值由「激活的 scalar 结果定义」生成：
        # 需要它配置为该数据类型并已加载，否则节点值不存在、查询为空。位移等节点绑定结果无需此步。
        set sdef_name ""
        set have_sdef 0
        set scs [rc$t GetSubcaseList]
        if {[llength $scs] > 0} {
            set binding [rc$t GetDataTypeBinding [lindex $scs 0] $datatype]
            if {[lsearch -exact {node element node_on_element} $binding] < 0} {
                # 返回 "(null)" 表示该数据类型在当前 subcase 不存在
                puts "HvToolkit::Query: datatype '$datatype' not found in result file!"
                set binding ""
            }
            if {[lsearch -exact {element node_on_element} $binding] >= 0} {
                puts "HvToolkit::Query: datatype '$datatype' is $binding-bound; node value = averaged/extrapolated"
                # GetActiveResult 仅在 MultiCore profile 存在：标准 profile 下命令不存在会抛错，
                # 用 catch 兜底；存在但失败/无结果时返回 0 或错误码，再由 GetResultHandle 返回值把关。
                set rid 0
                catch {set rid [rc$t GetActiveResult scalar]}
                if {$rid != 0 && [cl$t GetResultHandle sdef$t $rid scalar] == 0} {
                    set sdef_name sdef$t
                    set have_sdef 1
                    # 暂存原设置（查询后恢复）
                    set saved_mode ""
                    set saved_factor ""
                    set saved_factor_enabled ""
                    set saved_avg_across ""
                    set saved_datatype ""
                    catch {set saved_mode [sdef$t GetAverageMode]}
                    catch {set saved_factor [sdef$t GetAverageFactor]}
                    catch {set saved_factor_enabled [sdef$t GetAverageFactorEnabled]}
                    catch {set saved_avg_across [sdef$t GetAvgAcrossPartsEnable]}
                    catch {set saved_datatype [sdef$t GetDataType]}
                    # 数据类型设为应力（节点外推/平均值由此生成）
                    if {[sdef$t SetDataType $datatype] != 0} {
                        puts "HvToolkit::Query: SetDataType '$datatype' failed (result cached?); node stress may be empty"
                    }
                    # 显式控制平均模式（-averaging）
                    if {$averaging ne ""} {
                        if {[sdef$t SetAverageMode $averaging] != 0} {
                            puts "HvToolkit::Query: SetAverageMode '$averaging' failed (result cached?)"
                        }
                    }
                } else {
                    puts "HvToolkit::Query: no active scalar result definition (needs HyperView - MultiCore profile); node stress may be empty. Plot the stress contour first."
                }
            }
        }

        # 遍历 subcase（分析步） -> simulation（时间步）
        set result_list {}
        set qerr ""
        catch {
            foreach sc $scs {
                set nsim [rc$t GetNumberOfSimulations $sc]
                for {set si 0} {$si < $nsim} {incr si} {
                    if {[rc$t SetCurrentSubcase $sc] != 0} { error "SetCurrentSubcase failed (subcase $sc)" }
                    if {[rc$t SetCurrentSimulation $si] != 0} { error "SetCurrentSimulation failed (sim $si)" }

                    # 确保激活结果定义已加载该 subcase/simulation 的数据（生成节点外推/平均值）
                    if {$have_sdef} {
                        if {[rc$t LoadResult $rid scalar] != 0} {
                            puts "HvToolkit::Query: LoadResult failed (subcase $sc, sim $si)"
                        }
                    }

                    # 可选：该时间步的时间值（subcase GetSyncValue）
                    set time ""
                    if {[rc$t GetSubcaseHandle sub$t $sc] == 0} {
                        if {![catch {sub$t GetSyncValue $si} tv] && [string is double -strict $tv]} { set time $tv }
                        sub$t ReleaseHandle
                    }

                    # 每次重新取迭代器（快照随当前 simulation 变化）
                    if {[qc$t GetIteratorHandle it$t] != 0} { error "GetIteratorHandle failed" }
                    for {it$t First} {[it$t Valid]} {it$t Next} {
                        set data [it$t GetDataList]
                        lappend result_list [list $sc $si $time $data]
                    }
                    it$t ReleaseHandle
                }
            }
        } qerr

        # 恢复结果定义设置（无论成功失败）
        if {$sdef_name ne ""} {
            if {$saved_factor_enabled ne ""} { catch {sdef$t SetAverageFactorEnabled $saved_factor_enabled} }
            if {$saved_factor ne ""}          { catch {sdef$t SetAverageFactor $saved_factor} }
            if {$saved_avg_across ne ""}      { catch {sdef$t SetAvgAcrossPartsEnable $saved_avg_across} }
            if {$saved_datatype ne ""}        { catch {sdef$t SetDataType $saved_datatype} }
            if {$saved_mode ne ""}            { catch {sdef$t SetAverageMode $saved_mode} }
            sdef$t ReleaseHandle
        }

        qc$t ReleaseHandle
        sel$t ReleaseHandle
        rc$t ReleaseHandle
        m$t ReleaseHandle
        cl$t ReleaseHandle
        hwi CloseStack

        if {$qerr ne ""} {
            return -code error "Query failed: $qerr"
        }
        return $result_list
    }

    namespace ensemble create
}
