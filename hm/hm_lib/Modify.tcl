namespace eval HmToolkit::Modify {

    namespace export *

    namespace eval Create {

        namespace export *

        proc comps {names} {
            foreach name $names {
                set suffix 1
                set suffix_name $name
                while {[HmToolkit::Query exist comps name=$suffix_name]} {
                    set suffix_name "$name.$suffix"
                    incr suffix
                }
                    *createentity comps name=$suffix_name
            }

            *createmark comps 1 {*}[HmToolkit::Support range [expr - [llength $names]] 0]
            return [hm_getmark comps 1]
        }

        proc loadstep {name {type Static} {version new}} {
            set suffix 1
            set suffix_name $name
            while {[HmToolkit::Query exist loadsteps name=$suffix_name]} {
                set suffix_name "$name.$suffix"
                incr suffix
            }

            *createentity loadsteps name=$suffix_name
            set loadstepid [HmToolkit::Support currentids loadsteps 1]

            #set loadstep type
            switch $type {
                Static {
                    if {$version eq "new"} {*setvalue loadsteps id=$loadstepid STATUS=2 OS_TYPE=1}

                    *setvalue loadsteps id=$loadstepid STATUS=1 4709=1
                    *setvalue loadsteps id=$loadstepid STATUS=2 4059=1
                    *setvalue loadsteps id=$loadstepid STATUS=2 4060=STATICS

                    *setvalue loadsteps id=$loadstepid STATUS=2 3451=0
                    *setvalue loadsteps id=$loadstepid STATUS=2 4152=0
                }

                Mode {
                    if {$version eq "new"} {*setvalue loadsteps id=$loadstepid STATUS=2 OS_TYPE=3}

                    *setvalue loadsteps id=$loadstepid STATUS=1 4709=3
                    *setvalue loadsteps id=$loadstepid STATUS=2 4059=1
                    *setvalue loadsteps id=$loadstepid STATUS=2 4060=MODES

                    *setvalue loadsteps id=$loadstepid STATUS=2 9114=0
                }
                FreqResp {
                    if {$version eq "new"} {*setvalue loadsteps id=$loadstepid STATUS=2 OS_TYPE=6}

                    *setvalue loadsteps id=$loadstepid STATUS=1 4709=6
                    *setvalue loadsteps id=$loadstepid STATUS=2 4059=1
                    *setvalue loadsteps id=$loadstepid STATUS=2 4060=MFREQ

                    *setvalue loadsteps id=$loadstepid STATUS=2 9114=0
                }
                default {
                    if {$version eq "new"} {*setvalue loadsteps id=$loadstepid STATUS=2 OS_TYPE=0}

                    *setvalue loadsteps id=$loadstepid STATUS=1 4709=0
                    *setvalue loadsteps id=$loadstepid STATUS=2 4059=0
                    *setvalue loadsteps id=$loadstepid STATUS=2 4060="STATICS"
                }
            }

            return $loadstepid

        }

        proc loadcol {name} {
            set suffix 1
            set suffix_name $name
            while {[HmToolkit::Query exist loadcol name=$suffix_name]} {
                set suffix_name "$name.$suffix"
                incr suffix
            }

            *createentity loadcol name=$suffix_name
            return [HmToolkit::Support currentids loadcol 1]
        }

        proc grav {name {magnitude 9800} {vector {1 0 0}}} {
            set suffix 1
            set suffix_name $name
            while {[HmToolkit::Query exist loadcol name=$suffix_name]} {
                set suffix_name "$name.$suffix"
                incr suffix
            }

            *createentity loadcol name=$suffix_name
            set grav [HmToolkit::Support currentids loadcol 1]

            *setvalue loadcols id=$grav cardimage="GRAV"
            *setvalue loadcols id=$grav STATUS=2 2899=$magnitude
            *setvalue loadcols id=$grav STATUS=2 2900=[lindex $vector 0]
            *setvalue loadcols id=$grav STATUS=2 2901=[lindex $vector 1]
            *setvalue loadcols id=$grav STATUS=2 2902=[lindex $vector 2]

            return $grav
        }

        proc freqi {name f1 df ndf} {
            set suffix 1
            set suffix_name $name
            while {[HmToolkit::Query exist loadcol name=$suffix_name]} {
                set suffix_name "$name.$suffix"
                incr suffix
            }

            *createentity loadcol name=$suffix_name
            set freqi [HmToolkit::Support currentids loadcol 1]

            *setvalue loadcols id=$freqi cardimage="FREQi"

            *setvalue loadcols id=$freqi STATUS=2 3267=1
            *setvalue loadcols id=$freqi STATUS=0 7687=1
            *setvalue loadcols id=$freqi STATUS=2 7688=$f1
            *setvalue loadcols id=$freqi STATUS=2 7689=$df
            *setvalue loadcols id=$freqi STATUS=2 7690=$ndf

            return $freqi
        }

        proc eigen {name {v1 0} {v2 0} {nd 0}} {
            set suffix 1
            set suffix_name $name
            while {[HmToolkit::Query exist analysisparameters name=$suffix_name]} {
                set suffix_name "$name.$suffix"
                incr suffix
            }

            *createentity analysisparameters name=$suffix_name config=301
            set eigen [HmToolkit::Support currentids analysisparameters 1]

            if {$v1 ne 0} {*setvalue analysisparameters id=$eigen STATUS=1 v1=$v1}
            if {$v2 ne 0} {*setvalue analysisparameters id=$eigen STATUS=1 v2=$v2}
            if {$nd ne 0} {*setvalue analysisparameters id=$eigen STATUS=1 nd=$nd}

            return $eigen
        }

        proc dload {name {magnitude 9800} {SPCD_nodes {}} {comp "1 -999999 -999999 -999999 -999999 -999999"} {type ACCE}} {
            set suffix 1
            set suffix_name $name
            while {[HmToolkit::Query exist analysisparameters name=$suffix_name]} {
                set suffix_name "$name.$suffix"
                incr suffix
            }

            *createentity analysisparameters name=$suffix_name config=310
            set dload [HmToolkit::Support currentids analysisparameters 1]

            set excited [loadcol [format "%sExcited" $suffix_name]]
            set tc_curve [curve $magnitude $magnitude]

            if {[llength $SPCD_nodes]} {
                *createmark nodes 1 {*}$SPCD_nodes
                *loadcreate 1 3 2 {*}$comp
            }

            *setvalue analysisparameters id=$dload STATUS=1 dynamic_excitation_type=$type

            *setvalue analysisparameters id=$dload STATUS=2 rc_rb_flag=0
            *setvalue analysisparameters id=$dload STATUS=2 tc_tableid={curves $tc_curve}

            *setvalue analysisparameters id=$dload STATUS=2 exciteid={loadcols $excited}

            return $dload
        }

        proc damp {name {value 0.05}} {
            if {[HmToolkit::Query exist curve name=$name]} {return [HmToolkit::Query exist curve name=$name]}

            *createentity curves name=$name
            set damp [HmToolkit::Support currentids curves 1]

            *setvalue curves id=$damp STATUS=2 12300=1
            *setvalue curves id=$damp STATUS=2 12301=1

            if {[llength $value] eq 1} {
                *curveaddpoint $damp 0 0 $value
                *curveaddpoint $damp 1 9999 $value
            } else {
                set i 0
                foreach {x y} $value {
                    *curveaddpoint $damp $i $x $y
                    incr i
                }
            }

            return $damp
        }

        proc curve {name args} {
            if {[HmToolkit::Query exist curve name=$name]} {return [HmToolkit::Query exist curve name=$name]}

            *createentity curves name=$name
            set curve [HmToolkit::Support currentids curves 1]

            *setvalue curves id=$curve STATUS=2 12300=1
            *setvalue curves id=$curve STATUS=2 12301=2
            *setvalue curves id=$curve STATUS=2 11087=0
            *setvalue curves id=$curve STATUS=2 4128="LINEAR"
            *setvalue curves id=$curve STATUS=2 4129="LINEAR"
            *setvalue curves id=$curve STATUS=0 4653=0

            if {[llength $args] eq 1} {
                *curveaddpoint $curve 0 0 $args
                *curveaddpoint $curve 1 9999 $args
            } else {
                set i 0
                foreach {x y} $args {
                    *curveaddpoint $curve $i $x $y
                    incr i
                }
            }

            return $curve
        }

        proc material {name args} {
            if {[HmToolkit::Query exist mats name=$name]} {return [HmToolkit::Query exist mats name=$name]}

            *createentity mats cardimage=MAT1 includeid=0 name=$name
            set mat [HmToolkit::Support currentids mats 1]

            foreach {type value} $args {
                switch $type {
                    -E {*setvalue mats id=$mat STATUS=1 1=$value}
                    -G {*setvalue mats id=$mat STATUS=1 2=$value}
                    -NU {*setvalue mats id=$mat STATUS=1 3=$value}
                    -RHO {*setvalue mats id=$mat STATUS=1 4=$value}
                    default {}
                }
            }
            return $mat
        }

        proc shell_property {name t {mat 0}} {
            if {[HmToolkit::Query exist props name=$name]} {return [HmToolkit::Query exist props name=$name]}

            *createentity props cardimage=PSHELL includeid=0 name=$name

            set prop [HmToolkit::Support currentids props 1]
            *setvalue props id=$prop STATUS=1 95=$t

            if {$mat} {*setvalue props id=$prop materialid=$mat}

            return $prop
        }

        # [未调用] 创建 PSolid 实体属性。当前无调用，保留备用。
        proc solid_property {name {mat 0}} {
            if {[HmToolkit::Query exist props name=$name]} {return [HmToolkit::Query exist props name=$name]}

            *createentity props cardimage=PSOLID includeid=0 name=$name

            set prop [HmToolkit::Support currentids props 1]

            if {$mat} {*setvalue props id=$prop materialid=$mat}

            return $prop
        }

        proc beam_section {name type {params {}}} {
            if {[HmToolkit::Query exist beamsects name=$name]} {return [HmToolkit::Query exist beamsects name=$name]}

            if {[HmToolkit::Query exist beamsectcols name=$type]} {
                set beam_col [HmToolkit::Query exist beamsectcols name=$type]
            } else {
                *createentity beamsectcols includeid=0 name=$type
                set beam_col [HmToolkit::Query exist beamsectcols name=$type]
            }
  
            *createentity beamsects includeid=0 name=$name

            set section [HmToolkit::Support currentids beamsects 1]

            switch $type {
                Bar {
                    *setvalue beamsects id=$section sectiontype=1
                    *setvalue beamsects id=$section beamsect_dim1=[lindex $params 0]
                    *setvalue beamsects id=$section beamsect_dim2=[lindex $params 1]
                }
                Box {
                    *setvalue beamsects id=$section sectiontype=2
                    *setvalue beamsects id=$section beamsect_dim1=[lindex $params 0]
                    *setvalue beamsects id=$section beamsect_dim2=[lindex $params 1]
                    *setvalue beamsects id=$section beamsect_dim3=[lindex $params 2]
                    *setvalue beamsects id=$section beamsect_dim4=[lindex $params 3]
                }
                Rod {
                    *setvalue beamsects id=$section sectiontype=13
                    *setvalue beamsects id=$section beamsect_dim1=[lindex $params 0]
                }
                default {error "Unsupported beam section type: $type"}
            }

            return $section
        }

        proc beam_property {name {beam_section 0} {mat 0}} {
            if {[HmToolkit::Query exist props name=$name]} {return [HmToolkit::Query exist props name=$name]}

            *createentity props cardimage=PBEAML includeid=0 name=$name
            set prop [HmToolkit::Support currentids props 1]

            if {$beam_section} {*setvalue props id=$prop STATUS=1 3186=$beam_section}
            if {$mat} {*setvalue props id=$prop materialid=$mat}

            *createmark props 1 $prop
            *syncpropertybeamsectionvalues 1
            *clearmark props 1

            return $prop
        }

        proc bush_property {name {k "0 0 0 0 0 0"}} {
            if {[HmToolkit::Query exist props name=$name]} {return [HmToolkit::Query exist props name=$name]}

            *createentity props cardimage=PBUSH includeid=0 name=$name

            set prop [HmToolkit::Support currentids props 1]

            # 刚度输入开关
            *setvalue props id=$prop STATUS=2 872=1
            # 设置刚度值，刚度为负数时，设置为Rigid
            if {[lindex $k 0] < 0} {*setvalue props id=$prop STATUS=2 388=1
            } else {*setvalue props id=$prop STATUS=2 845=[lindex $k 0]}
            if {[lindex $k 1] < 0} {*setvalue props id=$prop STATUS=2 389=1
            } else {*setvalue props id=$prop STATUS=2 846=[lindex $k 1]}
            if {[lindex $k 2] < 0} {*setvalue props id=$prop STATUS=2 390=1
            } else {*setvalue props id=$prop STATUS=2 847=[lindex $k 2]}
            if {[lindex $k 3] < 0} {*setvalue props id=$prop STATUS=2 391=1
            } else {*setvalue props id=$prop STATUS=2 848=[lindex $k 3]}
            if {[lindex $k 4] < 0} {*setvalue props id=$prop STATUS=2 392=1
            } else {*setvalue props id=$prop STATUS=2 849=[lindex $k 4]}
            if {[lindex $k 5] < 0} {*setvalue props id=$prop STATUS=2 393=1
            } else {*setvalue props id=$prop STATUS=2 850=[lindex $k 5]}

            return $prop
        }

        proc Rbe2 {nodes {dof 123456} {independentnode 0}} {
            *elementtype rigid RBE2
            *createmark nodes 1 {*}$nodes
            if {$independentnode} {
                *rigidlink $independentnode 1 $dof
            } else {
                *rigidlinkinodecalandcreate 1 0 0 $dof
            }
            set rbe2 [HmToolkit::Support currentids elems]
            *setvalue elems id=$rbe2 STATUS=2 RIGID_ALPHA=0
            return $rbe2
        }

        proc Rbe3 {nodes main_node {dof 123456} {auto_weight 1}} {
            set n [llength $nodes]
            set nodes [lsort $nodes]

            if {!$main_node} {
                *createmark nodes 1 {*}$nodes
                set centroid [hm_getcentroid nodes 1]
                *createnode {*}$centroid
                set main_node [HmToolkit::Support currentids nodes 1]
            }

            set sum 0
            set inverse_dist ""
            for {set i 0} {$i < $n} {incr i} {
                set dist [HmToolkit::Query get_dist_nodes [lindex $nodes $i] $main_node]
                lappend inverse_dist [expr 1 / $dist]
                set sum [expr $sum + [lindex $inverse_dist $i]]
            }

            set para_dof ""
            set para_w ""
            for {set i 0} {$i < $n} {incr i} {
                lappend para_dof 123
                if {$auto_weight} {
                    lappend para_w [expr [lindex $inverse_dist $i] / $sum]
                } else {lappend para_w 1}
            }

            *elementtype rbe3 RBE3
            *createmark nodes 1 {*}$nodes
            *createarray $n {*}$para_dof
            *createdoublearray $n {*}$para_w
            *rbe3 1 1 $n 1 $n $main_node $dof 1
            set rbe3 [HmToolkit::Support currentids elems]
            *setvalue elems id=$rbe3 STATUS=2 RIGID_ALPHA=0

            return $rbe3
        }

        proc beam {node1 node2 {release1 0} {release2 0} {prop_name ""}} {
            *elementtype bar2 CBEAM

            # beam的X轴默认为节点1到节点2的方向，当节点1和节点2的方向平行于Z轴时，Spring的定义向量为Y轴方向，否则为Z轴方向
            set coord1 [HmToolkit::Query get_coord $node1 nodes]
            set coord2 [HmToolkit::Query get_coord $node2 nodes]
            set vector [HmToolkit::Support Vector sub $coord2 $coord1]

            if {[expr abs([lindex $vector 0]) < 0.01 && abs([lindex $vector 1]) < 0.01]} {
                *createvector 1 0 1 0
            } else {
                *createvector 1 0 0 1
            }

            *barelement $node1 $node2 1 0 0 $release1 $release2 $prop_name

            set beam [HmToolkit::Support currentids elems]
            *setvalue elems id=$beam STATUS=1 4842=BGG

            return $beam
        }

        proc spring {node1 node2 {prop_name ""}} {
            *elementtype spring CBUSH

            # Spring的X轴默认为节点1到节点2的方向，当节点1和节点2的方向平行于Z轴时，Spring的定义向量为Y轴方向，否则为Z轴方向
            set coord1 [HmToolkit::Query get_coord $node1 nodes]
            set coord2 [HmToolkit::Query get_coord $node2 nodes]
            set vector [HmToolkit::Support Vector sub $coord2 $coord1]

            if {[expr abs([lindex $vector 0]) < 0.01 && abs([lindex $vector 1]) < 0.01]} {
                set define_vector "0 1 0"
            } else {
                set define_vector "0 0 1"
            }

            *springos $node1 $node2 $prop_name 0 0 {*}$define_vector 1 0

            set spring [HmToolkit::Support currentids elems]
            return $spring
        }

        proc sets {name {type SET_ELEM}} {
            if {[HmToolkit::Query exist sets name=$name]} {return [HmToolkit::Query exist sets name=$name]}
            *createentity sets cardimage=$type includeid=0 name=$name
            return [HmToolkit::Support currentids sets 1]
        }

        namespace ensemble create

    }

    # 复制实体。keep_comp=1 时副本保留在源实体所在 component（*duplicatemark 第3参=0），
    # 默认 keep_comp=0 保持原 HyperMesh 行为：副本放入当前激活的 component（第3参=1）。
    proc Duplicate {type ids {keep_comp 0}} {
        *createmark $type 1 {*}$ids
        if {$keep_comp} {
            *duplicatemark $type 1 0
        } else {
            *duplicatemark $type 1 1
        }
        return [HmToolkit::Support currentids $type [llength $ids]]
    }

    proc Delete {type ids} {
        HmToolkit::Support remove_noexist $type ids
        if {![llength $ids]} {return 0}
        *createmark $type 2 {*}$ids
        *deletemark $type 2
    }

    # [未调用] 按距离延伸曲面。当前无调用，保留备用。
    proc extend_surf_by_dist {source_surf target_surf edge dist} {

        set connect_surfs [Surface get_connect_surfs $source_surf]

        *createmark surfaces 1 $source_surf
        *createmark lines 1 $edge
        *connect_surfaces_11 1 1 4 0 $dist 15 30 1 1 2 30 3 0

        set extended_surf [HmToolkit::Support currentids surf]

        *surfacemode 4

        *createmark surfaces 1 $extended_surf
        *createmark surfaces 2 $target_surf $connect_surfs

        set surfnum [HmToolkit::Support entitiesnum surf]
        *surfmark_trim_by_surfmark 1 2 0
        set new_surf_num [expr [HmToolkit::Support entitiesnum surf] - $surfnum]

        *createmark surfaces 2 {*}[HmToolkit::Support currentids surf $new_surf_num]
        *deletemark surfaces 2

        set surfnum [HmToolkit::Support entitiesnum surf]
        *createmark surfaces 2 $target_surf $connect_surfs
        *createmark surfaces 1 $extended_surf
        *surfmark_trim_by_surfmark 2 1 1
        set new_surf_num [expr [HmToolkit::Support entitiesnum surf] - $surfnum]

        return $new_surf_num
    }

    # [未调用] 曲面延伸至目标曲面。当前无调用，保留备用。
    proc extend_surf_to_surf {source_surf target_surfs edges {new 0}} {
        *createmark surfs 1 $source_surf {*}$target_surfs
        *createmark lines 1 {*}$edges 
        if {$new} {
            *connect_surfaces_11 1 1 3 1 0 75 15 1 0 1 30 18 0
        } else {
            *connect_surfaces_11 1 1 3 1 0 75 15 1 0 1 30 2 0
        }
    }
    
    proc project_entities_to_surf {entities_type entities surf {vector Normally}} {
        if {$vector eq "Normally"} {
            *createmark $entities_type 1 {*}$entities
            *markprojectnormallytosurface $entities_type 1 $surf
        } else {
            *createmark $entities_type 1 {*}$entities
            *createvector 1 {*}$vector
            *markprojecttosurface $entities_type 1 1 $surf
        }
        *clearmark $entities_type 1
        return $entities
    }

    proc project_curve_line_to_surf {curve_line target_surf {angle 0} {interpolation 0}} {
        if {!$interpolation} {
            set length [hm_getvalue lines id=$curve_line dataname=length]
            if {$length < 10} {
                set interpolation 10
            } elseif {$length < 50} {
                set interpolation 25
            } elseif {$length < 100} {
                set interpolation 50
            } elseif {$length < 500} {
                set interpolation [expr int($length / 5)]
            } else {set interpolation 100}
        }

        set points [lsort [HmToolkit::Modify split_line $curve_line $interpolation]]

        set double_list {}
        foreach point $points {
            set coord [HmToolkit::Query get_coord $point]
            set line_vec [lrange [hm_getlinetangentatcoordinate $curve_line {*}$coord] 3 5]
            set surf_vec [lrange [hm_getsurfacenormalatcoordinate $target_surf {*}$coord] 3 5]
            set project_vec [HmToolkit::Query get_rotate_vec $surf_vec $line_vec $angle]
            *createmark points 1 $point
            *createvector 1 {*}$project_vec
            *markprojecttosurface points 1 1 $target_surf
            set new_coord [HmToolkit::Query get_coord $point]
            if {[HmToolkit::Query get_dist $coord $new_coord] < 0.01} {continue}
            lappend double_list {*}$new_coord

        }

        HmToolkit::Modify Delete points $points

        if {[llength $double_list] <= 3} {return 0}
        *createdoublearray [llength $double_list] {*}$double_list
        *linecreatefromcoords 2 150 5 179 1 [llength $double_list]

        return [HmToolkit::Support currentids lines 1]
    }

    proc set_loadstep {loadstep args} {
        set ids {}
        foreach {type value} $args {
            switch $type {
                -SPC {
                    *setvalue loadsteps id=$loadstep STATUS=2 OS_SPCID={loadcols $value}
                    *setvalue loadsteps id=$loadstep STATUS=2 4143=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4144=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4145={Loadcols $value}
                    lappend ids $value
                }
                -load {
                    *setvalue loadsteps id=$loadstep STATUS=2 OS_LOADID={loadcols $value}
                    *setvalue loadsteps id=$loadstep STATUS=2 4143=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4146=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4147={Loadcols $value}
                    *setvalue loadsteps id=$loadstep STATUS=0 7763=0
                    *setvalue loadsteps id=$loadstep STATUS=1 7740={Loadcols 0}
                    lappend ids $value
                }
                -eigen {
                    *setvalue loadsteps id=$loadstep STATUS=2 OS_METHOD_STRUCTID={analysisparameters $value}
                    *setvalue loadsteps id=$loadstep STATUS=2 4143=1
                    *setvalue loadsteps id=$loadstep STATUS=1 5415=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4966={Analysisparameters $value}
                }
                -dload {
                    *setvalue loadsteps id=$loadstep STATUS=2 OS_DLOADID={analysisparameters $value}
                    *setvalue loadsteps id=$loadstep STATUS=2 4143=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4190=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4191={Analysisparameters $value}
                    lappend ids $value
                }
                -freqi {
                    *setvalue loadsteps id=$loadstep STATUS=2 OS_FREQID={loadcols $value}
                    *setvalue loadsteps id=$loadstep STATUS=2 4143=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4154=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4155={Loadcols $value}
                    lappend ids $value
                }
                -damp {
                    *setvalue loadsteps id=$loadstep STATUS=2 OS_SDAMPING_STRUCTID={curves $value}
                    *setvalue loadsteps id=$loadstep STATUS=2 4143=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4188=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4189={curves $value}
                }
                default {}
            }
        }
        *setvalue loadsteps id=$loadstep STATUS=2 ids=$ids
    }

    # [未调用] 旧版载荷步装配（与 set_loadstep 重复）。当前无调用，保留备用。
    proc set_loadstep_old {loadstep args} {
        set ids {}
        foreach {type value} $args {
            switch $type {
                -SPC {
                    *setvalue loadsteps id=$loadstep STATUS=2 4143=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4144=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4145={Loadcols $value}
                    lappend ids $value
                }
                -load {
                    *setvalue loadsteps id=$loadstep STATUS=2 4143=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4146=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4147={Loadcols $value}
                    *setvalue loadsteps id=$loadstep STATUS=0 7763=0
                    *setvalue loadsteps id=$loadstep STATUS=1 7740={Loadcols 0}
                    lappend ids $value
                }
                -eigen {
                    *setvalue loadsteps id=$loadstep STATUS=2 4143=1
                    *setvalue loadsteps id=$loadstep STATUS=1 5415=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4966={Analysisparameters $value}
                }
                -dload {
                    *setvalue loadsteps id=$loadstep STATUS=2 4143=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4190=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4191={Analysisparameters $value}
                    lappend ids $value
                }
                -freqi {
                    *setvalue loadsteps id=$loadstep STATUS=2 4143=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4154=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4155={Loadcols $value}
                    lappend ids $value
                }
                -damp {
                    *setvalue loadsteps id=$loadstep STATUS=2 4143=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4188=1
                    *setvalue loadsteps id=$loadstep STATUS=1 4189={curves $value}
                }
                default {}
            }
        }
        *setvalue loadsteps id=$loadstep STATUS=2 ids=$ids
    }

    proc split_line {line n} {
        *createdoublearray 2 0 1
        *nodecreateatlineparams $line 1 2 [expr $n-2] 1 1
        return [HmToolkit::Support currentids points $n]
    }

    proc discontinue_seam {line start_coord length interval {n 0}} {

        set dist [lindex [hm_findclosestpointonline {*}$start_coord $line] 3]
        if {$dist > 0.01} {return {}}

        set line_start [hm_getvalue lines id=$line dataname=startcoords]
        set line_end [hm_getvalue lines id=$line dataname=endcoords]
        if {[HmToolkit::Query get_dist $line_start $start_coord] > [HmToolkit::Query get_dist $line_end $start_coord]} {
            set end_coord $line_start
        } else {set end_coord $line_end}

        set line_length [HmToolkit::Query get_dist $start_coord $end_coord]

        if {$n > 0} {
            if {$n == 1} {set length $line_length} else {
                set total [expr ($line_length - $length) / ($n - 1)]
                if {$total > $length} {
                    set interval [expr $total - $length]
                } else {
                    set length $line_length
                    set interval 0
                }
            }
        }

        set flag 1
        set res {}

        set index 0
        while {1} {
            incr index
            if {$index > 4096} {return $res}
            if {$flag} {
                set flag 0
                if {[expr $line_length - $length] > 1} {
                    set coords [hm_getlinepointsatdistance $line $length {*}$start_coord]
                    if {[llength $coords] == 3} {
                        set split_coord $coords
                    } else {
                        if {[HmToolkit::Query get_dist [lrange $coords 0 2] $end_coord] < [HmToolkit::Query get_dist [lrange $coords 3 5] $end_coord]} {
                            set split_coord [lrange $coords 0 2]
                        } else {set split_coord [lrange $coords 3 5]} 
                    }

                    *linecreatestraight {*}$start_coord {*}$split_coord
                    lappend res [HmToolkit::Support currentids lines 1]

                    set start_coord $split_coord
                    set line_length [HmToolkit::Query get_dist $start_coord $end_coord]

                } else {
                    *linecreatestraight {*}$start_coord {*}$end_coord
                    lappend res [HmToolkit::Support currentids lines 1]
                    break
                }

            } else {
                set flag 1
                if {[expr $line_length - $interval] > 1} {
                    set coords [hm_getlinepointsatdistance $line $interval {*}$start_coord]
                    if {[llength $coords] == 3} {
                        set start_coord $coords
                    } else {
                        if {[HmToolkit::Query get_dist [lrange $coords 0 2] $end_coord] < [HmToolkit::Query get_dist [lrange $coords 3 5] $end_coord]} {
                            set start_coord [lrange $coords 0 2] 
                        } else {set start_coord [lrange $coords 3 5]}
                    }

                    set line_length [HmToolkit::Query get_dist $start_coord $end_coord]

                } else {break}
            }
        }

        return $res
    }

    # [未调用] 在点处拆线。当前无调用，保留备用（合理公共工具）。
    proc split_line_at_point {line point} {
        *createmark points 1 $point
        *nodecreateatpointmark 1
        set node [HmToolkit::Support currentids nodes 1]
        return [HmToolkit::Support get_creation_rec lines {*linesplitatpoint $line 2}]
    }

    proc split_surf_with_lines {surf lines {tolerance 0.05}} {
        *createmark surfaces 1 $surf
        *createmark lines 2 {*}$lines

        set new_surfs [HmToolkit::Support get_creation_rec surfs {*surfacemarksplitwithlines 1 2 0 12 $tolerance}]
        lappend new_surfs $surf

        return $new_surfs
    }

    proc add_points_on_surface {surf points} {
        foreach point $points {
            *surfaceaddpoint $surf [hm_getvalue points id=$point dataname=x] [hm_getvalue points id=$point dataname=y] [hm_getvalue points id=$point dataname=z]
        }
        HmToolkit::Modify Delete points $points
    }

    proc get_mid_point {line} {
        *createdoublearray 1 0.5
        *nodecreateatlineparams $line 1 1 0 0 1
        return [HmToolkit::Support currentids points]
    }

    proc patch {lines {tangency nontangent}} {
        *createmark lines 1 {*}$lines
        *surfacesplineonlinesloop 1 1 0 8
        *clearmark lines 1
        return [HmToolkit::Support currentids surfs 1]
    }

    proc patch_coords {coords} {
        set n [llength $coords]
        if {$n < 3} {return 0}
        foreach c $coords {
            *createpoint {*}$c 0
        }
        set points [HmToolkit::Support currentids points $n]
        *createmark points 1 {*}$points
        *splinesurface points 1 0 1 1024
        HmToolkit::Modify Delete points $points
        return [HmToolkit::Support currentids surfs 1]
    }

    proc offset_edge {edge offset {trim 0}} {
        set surf [hm_getsurfacesfromedge $edge]
        set surf_edges [concat {*}[hm_getsurfaceedges $surf]]
        set connect_edges [HmToolkit::Query get_connect_edges $edge]

        set cedge1 0
        set cedge2 0
        set cangle1 90
        set cangle2 90
        set v1coord [HmToolkit::Query get_coord [lindex $connect_edges 0]]
        set v2coord [HmToolkit::Query get_coord [lindex $connect_edges 2]]

        foreach cedge [lindex $connect_edges 1] {
            if {$cedge in $surf_edges} {} else {continue}
            set angle [HmToolkit::Query get_angle_line_line $cedge $edge $v1coord]
            if {$angle < 5 || $angle > 175} {continue}
            if {[hm_getgeomtopologytype lines $cedge] eq "free"} {
                set cedge1 $cedge
                break
            }
            if {[hm_getgeomtopologytype lines $cedge] eq "suppressed"} {continue}
            set cangle [expr abs($angle - 90)]
            if {$cangle < $cangle1} {
                set cedge1 $cedge
                set cangle1 $cangle
            }
        }
        foreach cedge [lindex $connect_edges 3] {
            if {$cedge in $surf_edges} {} else {continue}
            set angle [HmToolkit::Query get_angle_line_line $cedge $edge $v2coord]
            if {$angle < 5 || $angle > 175} {continue}
            if {[hm_getgeomtopologytype lines $cedge] eq "free"} {
                set cedge2 $cedge
                break
            }
            if {[hm_getgeomtopologytype lines $cedge] eq "suppressed"} {continue}
            set cangle [expr abs($angle - 90)]
            if {$cangle < $cangle2} {
                set cedge2 $cedge
                set cangle2 $cangle
            }
        }

        if {$cedge1} {
            set cvec [lrange [hm_getlinetangentatcoordinate $cedge1 {*}$v1coord] 3 5]
            set line_vec [lrange [hm_getlinetangentatcoordinate $edge {*}$v1coord] 3 5]
            set cos [HmToolkit::Query get_cos_vec $cvec $line_vec]
            set sin [expr (1 - ($cos**2))**0.5]
            set correct_dist [expr $offset / $sin]
            if {[catch {set new_coord [hm_getlinepointsatdistance $cedge1 $correct_dist {*}$v1coord]}]} {
                set vertices [hm_getverticesfromedge $cedge1]
                set c1 [HmToolkit::Query get_coord [lindex $vertices 0]]
                set c2 [HmToolkit::Query get_coord [lindex $vertices 1]]
                if {[HmToolkit::Query get_dist $v1coord $c1] > [HmToolkit::Query get_dist $v1coord $c2]} {set new_coord $c1} else {set new_coord $c2}
            }
            *createpoint {*}$new_coord
            set point1 [HmToolkit::Support currentids points 1]
        } else {
            set line_vec [lrange [hm_getlinetangentatcoordinate $edge {*}$v1coord] 3 5]
            set surf_vec [lrange [hm_getsurfacenormalatcoordinate $surf {*}$v1coord] 3 5]
            set cross_vec [HmToolkit::Support Vector cross $line_vec $surf_vec]
            set cross_vec [HmToolkit::Support Vector mul $cross_vec $offset]
            set new_coord [HmToolkit::Support Vector add $v1coord $cross_vec]
            if {[lindex [hm_findclosestpointonsurface {*}$new_coord $surf] 3] > 0.01} {
                set cross_vec [HmToolkit::Support Vector mul $cross_vec -1]
                set new_coord [HmToolkit::Support Vector add $v1coord $cross_vec]
            }
            *createpoint {*}$new_coord
            set point1 [HmToolkit::Support currentids points 1]
        }

        if {$cedge2} {
            set cvec [lrange [hm_getlinetangentatcoordinate $cedge2 {*}$v2coord] 3 5]
            set line_vec [lrange [hm_getlinetangentatcoordinate $edge {*}$v2coord] 3 5]
            set cos [HmToolkit::Query get_cos_vec $cvec $line_vec]
            set sin [expr (1 - ($cos**2))**0.5]
            set correct_dist [expr $offset / $sin]
            if {[catch {set new_coord [hm_getlinepointsatdistance $cedge2 $correct_dist {*}$v2coord]}]} {
                set vertices [hm_getverticesfromedge $cedge2]
                set c1 [HmToolkit::Query get_coord [lindex $vertices 0]]
                set c2 [HmToolkit::Query get_coord [lindex $vertices 1]]
                if {[HmToolkit::Query get_dist $v2coord $c1] > [HmToolkit::Query get_dist $v2coord $c2]} {set new_coord $c1} else {set new_coord $c2}
            }
            *createpoint {*}$new_coord
            set point2 [HmToolkit::Support currentids points 1]
        } else {
            set line_vec [lrange [hm_getlinetangentatcoordinate $edge {*}$v2coord] 3 5]
            set surf_vec [lrange [hm_getsurfacenormalatcoordinate $surf {*}$v2coord] 3 5]
            set cross_vec [HmToolkit::Support Vector cross $line_vec $surf_vec]
            set cross_vec [HmToolkit::Support Vector mul $cross_vec $offset]
            set new_coord [HmToolkit::Support Vector add $v2coord $cross_vec]
            if {[lindex [hm_findclosestpointonsurface {*}$new_coord $surf] 3] > 0.01} {
                set cross_vec [HmToolkit::Support Vector mul $cross_vec -1]
                set new_coord [HmToolkit::Support Vector add $v2coord $cross_vec]
            }
            *createpoint {*}$new_coord
            set point2 [HmToolkit::Support currentids points 1]
        }

        *createlist points 1 $point1 $point2
        *linecreatefromnodesonsurface surfs $surf points 1 2 0
        HmToolkit::Modify Delete points "$point1 $point2"

        return [HmToolkit::Support currentids lines 1]
    }

    proc surfs_stitch {surfs {tolerance 0.05}} {
        set original_tolerance [hm_getoption cleanup_tolerance]
        *setoption cleanup_tolerance=$tolerance
        *createmark surfaces 1 {*}$surfs
        *multi_surfs_lines_merge 1 0 0
        *setoption cleanup_tolerance=$original_tolerance
    }

    proc project_line_to_line {source_line target_line} {
        set start_coord [hm_getvalue lines id=$source_line dataname=startcoords]
        set end_coord [hm_getvalue lines id=$source_line dataname=endcoords]
        set dist1 [lindex [hm_findclosestpointonline {*}$start_coord $target_line] 3]
        set dist2 [lindex [hm_findclosestpointonline {*}$end_coord $target_line] 3]

        *createdoublearray 6 {*}$start_coord {*}$end_coord
        *createmark lines 1 $target_line
        set pn [llength [hm_entitylist lines id]]
        *lineimprintpoints 1 1 6 -1
        set cn [llength [hm_entitylist lines id]]
        if {[HmToolkit::Query exist lines id=$target_line]} {return $target_line}
        switch [expr $cn - $pn] {
            0 {set new_lines [HmToolkit::Support currentids lines 1]}
            1 {set new_lines [HmToolkit::Support currentids lines 2]}
            2 {set new_lines [HmToolkit::Support currentids lines 3]}
            default {set new_lines {}}
        }

        set target_line 0
        foreach line $new_lines {
            set new_dist1 [lindex [hm_findclosestpointonline {*}$start_coord $line] 3]
            if {$new_dist1 - $dist1 > 0.01} {
                HmToolkit::Modify Delete lines $line
                continue
            }
            set new_dist2 [lindex [hm_findclosestpointonline {*}$end_coord $line] 3]
            if {$new_dist2 - $dist2 > 0.01} {
                HmToolkit::Modify Delete lines $line
                continue
            }
            set target_line $line
        }
        return $target_line
    }

    # [未调用] 四边形转三角形。当前无调用，保留备用。
    proc quad_to_tria {elems} {
        *createmark elems 1 {*}$elems
        set size [hm_getaverageelemsize 1]
        set previous [hm_entitymaxid elems]
        incr previous
        *defaultremeshelems 1 $size 0 0 1 1 1 14 0 0 0 0 2 30
        set current [hm_entitymaxid elems]
        set num [expr $current - $previous]
        return "$previous\-$current"
    }

    # [未调用] 节点缝合。当前无调用，保留备用。
    proc stitch_nodes {n1 n2 {mid 1}} {
        hm_answernext yes
        *replacenodes $n1  $n2 1 $mid
    }

    proc move {type entities vector {dist 1}} {
        *createmark $type 1 {*}$entities
        *createvector 1 {*}$vector
        *translatemark $type 1 1 $dist
        *clearmark $type 1
    }

    proc position {type entities source target {sys 0}} {
        if {$sys} {
            set vec [HmToolkit::Support Vector sub $target $source]
            set dist [HmToolkit::Support Vector m $vec]
            puts vec:$vec 
            puts dist:$dist
            *createvector 1 {*}$vec
            *createmark $type 1 {*}$entities
            *translatemarkwithsystem $type 1 1 $dist $sys
        } else {
            *createmark $type 1 {*}$entities
            *positionentity $type mark=1 "source_coords=$source" "target_coords=$target"
        }
    }

    # 导出求解器文件（ASCII 分析文件）。依据 *feoutputwithdata 帮助文档实现：
    #   *feoutputwithdata export_template filename 0 0 export_type 1 n_strings
    # filename    : 输出文件完整路径，如 C:/model.fem
    # solver      : 求解器模板目录名，默认 optistruct
    # export_type : 0=仅显示实体 1=全部实体 2=按输出位导出（默认 1）
    # options     : 附加导出选项字符串数组（可选），如 {CONNECTORS_SKIP HMCOMMENTS_SKIP}；
    #               有效选项因求解器而异，见 *feoutputwithdata 的子主题文档
    proc export_solver_file {filename {solver optistruct} {export_type 1} {options {}}} {
        # TEMPLATES_DIR 返回 <...>/hwdesktop/templates（不含 feoutput），
        # 导出模板主文件固定位于 <templates>/feoutput/<solver>/<solver>
        set base [hm_info -appinfo SPECIFIEDPATH TEMPLATES_DIR]
        set export_template [file join $base feoutput $solver $solver]
        if {![file exists $export_template]} {
            error "未找到求解器导出模板: $export_template"
        }

        set n [llength $options]
        if {$n} {
            *createstringarray $n {*}$options
        }

        # 路径直接作为单个 Tcl 参数传入（统一为正斜杠，与录制命令一致）；
        # 不要额外加引号——内嵌引号会被 HM 再次转义（变成 ""...""）并破坏路径。
        # 反斜杠转正斜杠用 regsub（string map {\ /} 在 Tcl 8.5 会报 list unbalanced）。
        *feoutputwithdata [regsub -all {\\} $export_template {/}] [regsub -all {\\} $filename {/}] 0 0 $export_type 1 $n
    }

    namespace ensemble create

}
