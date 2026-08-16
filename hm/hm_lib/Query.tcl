namespace eval HmToolkit::Query {

    namespace export *

    proc get_connect_surfs {surf} {
        set edges [concat {*}[hm_getsurfaceedges $surf]]
        set res {}
        foreach edge $edges {
            if {[hm_getgeomtopologytype lines $edge] ne "free"} {
                lappend res {*}[hm_getsurfacesfromedge $edge]
            }
        }
        HmToolkit::Support lunique res
        HmToolkit::Support lremove res $surf

        return $res

    }

    proc get_connect_edges {edge} {
        set vertices [hm_getverticesfromedge $edge]

        set edges1 [hm_getedgesfromvertex [lindex $vertices 0]]
        set edges2 [hm_getedgesfromvertex [lindex $vertices 1]]

        HmToolkit::Support lremove edges1 $edge
        HmToolkit::Support lremove edges2 $edge

        return [lappend {} [lindex $vertices 0] $edges1 [lindex $vertices 1] $edges2]
    }

    proc get_angle_line_line {line1 line2 coords} {
        set vec1 [lrange [hm_getlinetangentatcoordinate $line1 {*}$coords] 3 5]
        set vec2 [lrange [hm_getlinetangentatcoordinate $line2 {*}$coords] 3 5]

        set cos_theta [get_cos_vec $vec1 $vec2]
        if {$cos_theta > 1} {set cos_theta 1} elseif {$cos_theta < -1} {set cos_theta -1}
        set theta [expr {acos($cos_theta)}]
        set theta [expr {$theta * 180 / 3.14159}]

        return $theta
    }

    # [未调用] 线与面夹角（AutoSeam 用 _start/_end 变体）。当前无调用，保留备用。
    proc get_angle_line_surf {line surf} {

        set value [hm_getclosestpointsbetweenlinesurface $line $surf]
        set line_vec [lrange [hm_getlinetangentatcoordinate $line [lindex $value 3] [lindex $value 4] [lindex $value 5]] 3 5]
        set surf_vec [lrange [hm_getsurfacenormalatcoordinate $surf [lindex $value 3] [lindex $value 4] [lindex $value 5]] 3 5]

        set cos_theta [get_cos_vec $line_vec $surf_vec]
        if {$cos_theta > 1} {set cos_theta 1} elseif {$cos_theta < -1} {set cos_theta -1}
        set theta [expr {acos($cos_theta)}]
        set theta [expr {$theta * 180 / 3.14159}]

        return $theta
    }

    proc get_angle_line_surf_start {line surf} {
        set start [hm_getvalue lines id=$line dataname=startcoords]
        set line_vec [lrange [hm_getlinetangentatcoordinate $line {*}$start] 3 5]
        set surf_vec [lrange [hm_getsurfacenormalatcoordinate $surf {*}$start] 3 5]

        set cos_theta [get_cos_vec $line_vec $surf_vec]
        if {$cos_theta > 1} {set cos_theta 1} elseif {$cos_theta < -1} {set cos_theta -1}
        set theta [expr {acos($cos_theta)}]
        set theta [expr {$theta * 180 / 3.14159}]

        return $theta
    }

    proc get_angle_line_surf_end {line surf} {
        set end [hm_getvalue lines id=$line dataname=endcoords]
        set line_vec [lrange [hm_getlinetangentatcoordinate $line {*}$end] 3 5]
        set surf_vec [lrange [hm_getsurfacenormalatcoordinate $surf {*}$end] 3 5]

        set cos_theta [get_cos_vec $line_vec $surf_vec]
        if {$cos_theta > 1} {set cos_theta 1} elseif {$cos_theta < -1} {set cos_theta -1}
        set theta [expr {acos($cos_theta)}]
        set theta [expr {$theta * 180 / 3.14159}]

        return $theta
    }

    proc get_angle_surf_surf {surf1 surf2 coord} {
        set vec1 [lrange [hm_getsurfacenormalatcoordinate $surf1 {*}$coord] 3 5]
        set vec2 [lrange [hm_getsurfacenormalatcoordinate $surf2 {*}$coord] 3 5]

        set cos_theta [get_cos_vec $vec1 $vec2]
        if {$cos_theta > 1} {set cos_theta 1} elseif {$cos_theta < -1} {set cos_theta -1}
        set theta [expr {acos($cos_theta)}]
        set theta [expr {$theta * 180 / 3.14159}]

        return $theta
    }

    # [未调用] 线与面距离。当前无调用，保留备用。
    proc get_dist_line_surf {line surf} {

        set start [hm_getvalue lines id=$line dataname=startcoords]
        set end [hm_getvalue lines id=$line dataname=endcoords]

        set dist [expr {([lindex [hm_getdistancefromnearestsurface $start $surf] 0] + [lindex [hm_getdistancefromnearestsurface $end $surf] 0]) / 2}]

        return $dist
    }

    # [未调用] 点到线距离。当前无调用，保留备用。
    proc get_dist_coord_line {coord line} {
        return [lindex [hm_findclosestpointonline {*}$coord $line] 3]
    }

    # [未调用] 投影比例。当前无调用，保留备用。
    proc get_project_proportion {line surf} {
        set startcoord [hm_getvalue lines id=$line dataname=startcoords]
        set endcoord [hm_getvalue lines id=$line dataname=endcoords]
        set p1 [hm_findclosestpointonsurface {*}$startcoord $surf]
        set p2 [hm_findclosestpointonsurface {*}$endcoord $surf]

        set pl [HmToolkit::Query get_dist $p1 $p2]
        set initl [hm_getvalue lines id=$line dataname=length]

        if {[expr [get_dist $p1 $startcoord] < 0.01] && [expr [get_dist $p2 $endcoord] < 0.01 ]} {
            return 0
        } else {
            return [expr $pl / $initl]
        }
    }

    proc get_project_vector {line surf angle} {
        set mid_point [HmToolkit::Modify get_mid_point $line]
        set mid_coords [HmToolkit::Query get_coord $mid_point]

        HmToolkit::Modify Delete points $mid_point

        set line_vec [lrange [hm_getlinetangentatcoordinate $line {*}$mid_coords] 3 5]
        set surf_vec [lrange [hm_getsurfacenormalatcoordinate $surf {*}$mid_coords] 3 5]

        return [get_rotate_vec $surf_vec $line_vec $angle]
    }

    proc get_cos_vec {vec1 vec2} {
        return [expr [lindex $vec1 0] * [lindex $vec2 0] + [lindex $vec1 1] * [lindex $vec2 1] + [lindex $vec1 2] * [lindex $vec2 2]]
    }

    proc get_rotate_vec {vec axis theta} {
        set theta [expr $theta * 3.14159 / 180]
        set r1 [HmToolkit::Support Vector mul $vec  [expr cos($theta)]]
        set r2 [HmToolkit::Support Vector mul [HmToolkit::Support Vector cross $axis $vec] [expr sin($theta)]]
        set dot [HmToolkit::Support Vector dot $axis $vec]
        set r3 [HmToolkit::Support Vector mul $axis [expr $dot * (1-cos($theta))]]

        return [HmToolkit::Support Vector add $r1 $r2 $r3]
    }

    proc get_dist {coord1 coord2} {
        set res [expr ([lindex $coord1 0] - [lindex $coord2 0])**2 +\
        ([lindex $coord1 1] - [lindex $coord2 1])**2 +\
        ([lindex $coord1 2] - [lindex $coord2 2])**2]
        return [expr $res**0.5]
    }

    proc get_coord {point {type points} {local_system 0}} {
        if {$type eq "nodes" || $type eq "node"} {
            return [hm_xformnodetolocal $point $local_system]
        }
        return "[hm_getvalue $type id=$point dataname=x] [hm_getvalue $type id=$point dataname=y] [hm_getvalue $type id=$point dataname=z]"
    }

    proc get_dist_nodes {node1 node2} {
        set c1 [get_coord $node1 node]
        set c2 [get_coord $node2 node]
        return [get_dist $c1 $c2]
    }

    proc get_surf_vertexs {surf} {
        set edges [concat {*}[hm_getsurfaceedges $surf]]
        set vertices {}
        foreach edge $edges {
            if {[hm_getgeomtopologytype lines $edge] in "free shared"} {
                set edge_vertice [hm_getverticesfromedge $edge]
                if {[lindex $edge_vertice 0] ni $vertices && [lindex $edge_vertice 0]}  {
                    lappend vertices [lindex $edge_vertice 0]
                }
                if {[lindex $edge_vertice 1] ni $vertices && [lindex $edge_vertice 1]}  {
                    lappend vertices [lindex $edge_vertice 1]
                }
            }
        }
        return $vertices
    }

    proc exist {type name_or_id} {
        set arg [split $name_or_id =]
        if {[llength $arg] ne 2} {error "worng input name_or_id:$name_or_id, should be name=value or id=value"}
        switch [lindex $arg 0] {
            name {
                if {[catch {hm_getvalue $type name=[lindex $arg 1] dataname=id} var]} {
                    return false
                } else {
                    return $var
                }
            }
            id {
                if {[catch {hm_getvalue $type id=[lindex $arg 1] dataname=id} var]} {
                    return false
                } else {
                    return $var
                }
            }
            default {
                error "worng arg name_or_id:$name_or_id, should be name=value or id=value"
            }
        }
    }

    proc same_line {line1 line2} {
        set value [hm_getclosestpointsbetweentwolines $line1 $line2]
        set coord1 [lrange $value 0 2]
        set coord2 [lrange $value 3 5]

        set dist [get_dist $coord1 $coord2]

        if {$dist > 0.01} {return 0}

        set vec1 [lrange [hm_getlinetangentatcoordinate $line1 {*}$coord1] 3 5]
        set vec2 [lrange [hm_getlinetangentatcoordinate $line2 {*}$coord2] 3 5]

        if {[get_cos_vec $vec1 $vec2] < 0.99} {
            if {[get_cos_vec $vec1 $vec2] > -0.99} {
                return 0
            }
        }
        return 1
    }

    # [未调用] 最小距离（get_max_dist 在 detect_hole 使用）。当前无调用，保留备用。
    proc get_min_dist {type points} {
        set dist inf
        set n [llength $points]
        for {set i 0} {$i < $n} {incr i} {
            set pi [lindex $points $i]
            for {set j $i} {$j < $n} {incr j} {
                set pj [lindex $points $j]
                if {[lindex [hm_getdistance $type $pi $pj 0] 0] < $dist} {set dist [lindex [hm_getdistance $type $pi $pj 0] 0]}
            }
        }
        return $dist
    }

    proc get_max_dist {type points} {
        set dist 0
        set n [llength $points]
        for {set i 0} {$i < $n} {incr i} {
            set pi [lindex $points $i]
            for {set j $i} {$j < $n} {incr j} {
                set pj [lindex $points $j]
                if {[lindex [hm_getdistance $type $pi $pj 0] 0] > $dist} {set dist [lindex [hm_getdistance $type $pi $pj 0] 0]}
            }
        }
        return $dist
    }

    proc detect_hole {type entities {tube 0}} {
        hm_holedetectioninit
        *createmark $type 1 {*}$entities
        hm_holedetectionsetentities $type 1
        if {$tube} {
            hm_holedetectionsettubeparams tube_shape=31 tube_type=0
            hm_holedetectionfindholes 7
        } else {
            hm_holedetectionsetholeparams hole_shape=31
            hm_holedetectionfindholes 1
        }

        set hole_num [hm_holedetectiongetnumberofholes]
        set res_infos {}
        while {$hole_num > 0} {
            incr hole_num -1
            set h_info [hm_holedetectiongetholedetails $hole_num]
            set flag1 [lindex $h_info 0]
            set flag2 [lindex $h_info 1]
            if {$flag1 == 0} {
                switch $flag2 {
                    0 {
                        set type General
                        set size 0
                        set center [lindex $h_info 2]
                        set axis [lindex $h_info 3]
                        set hole_entities [lindex $h_info 4]
                        if {[lindex $hole_entities 0] eq "nodes"} {
                            set size [expr [get_max_dist nodes [lrange $hole_entities 1 end]] / 2]
                        }
                        set washer [lindex $h_info 5]
                    }
                    1 {
                        set type Circular
                        set size [lindex $h_info 2]
                        set center [lindex $h_info 3]
                        set axis [lindex $h_info 4]
                        set hole_entities [lindex $h_info 5]
                        set washer [lindex $h_info 6]
                    }
                    2 {
                        set type Rounded

                        set r1 [lindex $h_info 2]
                        set r2 [lindex $h_info 4]
                        set size [expr ($r1 + $r2) / 2]

                        set c1 [lindex $h_info 3]
                        set c2 [lindex $h_info 5]
                        set center [HmToolkit::Support Vector add $c1 $c2]
                        set center [HmToolkit::Support Vector mul $center 0.5]
                        set axis [lindex $h_info 8]
                        set hole_entities [lindex $h_info 9]
                        set washer [lindex $h_info 10]
                    }
                    3 {
                        set type Square
                        set size [expr [lindex $h_info 2] / 2]
                        set center [lindex $h_info 3]
                        set axis [lindex $h_info 4]
                        set hole_entities [lindex $h_info 5]
                        set washer [lindex $h_info 6]
                    }
                    4 {
                        set type Rectangular
                        set size1 [lindex $h_info 2]
                        set size2 [lindex $h_info 3]
                        set size [expr ($size1 + $size2) / 4]
                        set center [lindex $h_info 4]
                        set axis [lindex $h_info 5]
                        set hole_entities [lindex $h_info 6]
                        set washer [lindex $h_info 7]
                    }
                } 
            } else {

                switch $flag2 {
                    0 {
                        set type GeneralTube
                        set size 0
                        set entities_top [lindex $h_info 4]
                        set entities_buttom [lindex $h_info 10]
                        if {[lindex $entities_top 0] eq "nodes" && [lindex $entities_buttom 0] eq "nodes"} {
                            set size_top [get_max_dist nodes [lrange $entities_top 1 end]]
                            set size_buttom [get_max_dist nodes [lrange $entities_buttom 1 end]]
                            set size [expr ($size_top + $size_buttom) / 4]
                        }

                        set center_top [lindex $h_info 2]
                        set center_buttom [lindex $h_info 8]
                        set center [HmToolkit::Support Vector add $center_top $center_buttom]
                        set center [HmToolkit::Support Vector mul $center 0.5]

                        set axis_top [lindex $h_info 3]
                        set axis_buttom [lindex $h_info 9]
                        set axis [HmToolkit::Support Vector add $axis_top $axis_buttom]
                        if {[HmToolkit::Support Vector m $axis] < 0.01} {set axis [HmToolkit::Support Vector sub $axis_top $axis_buttom]}
                        set axis [HmToolkit::Support Vector mul $axis 0.5]

                        set entities_list [lindex $h_info 6]
                        set hole_entities nodes
                        if {[lindex $entities_list 0] eq "solids"} {
                            foreach {elem face} [lrange $entities_list 1 end] {
                                incr face
                                lappend hole_entities {*}[hm_getvalue elems id=$elem dataname=facenodes$face]
                            }
                            HmToolkit::Support lunique hole_entities
                        }
                        set washer 0
                    }
                    1 {
                        set type CircularTube

                        set r_top [lindex $h_info 2]
                        set r_buttom [lindex $h_info 9]
                        set size [expr ($r_top + $r_buttom) / 2]

                        set center_top [lindex $h_info 3]
                        set center_buttom [lindex $h_info 10]
                        set center [HmToolkit::Support Vector add $center_top $center_buttom]
                        set center [HmToolkit::Support Vector mul $center 0.5]

                        set axis_top [lindex $h_info 4]
                        set axis_buttom [lindex $h_info 11]
                        set axis [HmToolkit::Support Vector add $axis_top $axis_buttom]
                        set axis [HmToolkit::Support Vector mul $axis 0.5]

                        set entities_list [lindex $h_info 7]
                        set hole_entities nodes
                        if {[lindex $entities_list 0] eq "solids"} {
                            foreach {elem face} [lrange $entities_list 1 end] {
                                incr face
                                lappend hole_entities {*}[hm_getvalue elems id=$elem dataname=facenodes$face]
                            }
                            HmToolkit::Support lunique hole_entities
                        }
                        set washer 0
                    }
                    2 {
                        set type RoundedTube

                        set r1_top [lindex $h_info 2]
                        set r2_top [lindex $h_info 4]
                        set r_top [expr ($r1_top + $r2_top) / 2]
                        set r1_buttom [lindex $h_info 13]
                        set r2_buttom [lindex $h_info 15]
                        set r_buttom [expr ($r1_buttom  + $r2_buttom ) / 2]
                        set size [expr ($r_top + $r_buttom) / 2]

                        set center_top [lindex $h_info 7]
                        set center_buttom [lindex $h_info 18]
                        set center [HmToolkit::Support Vector add $center_top $center_buttom]
                        set center [HmToolkit::Support Vector mul $center 0.5]

                        set axis_top [lindex $h_info 8]
                        set axis_buttom [lindex $h_info 19]
                        set axis [HmToolkit::Support Vector add $axis_top $axis_buttom]
                        set axis [HmToolkit::Support Vector mul $axis 0.5]

                        set entities_list [lindex $h_info 11]
                        set hole_entities nodes
                        if {[lindex $entities_list 0] eq "solids"} {
                            foreach {elem face} [lrange $entities_list 1 end] {
                                incr face
                                lappend hole_entities {*}[hm_getvalue elems id=$elem dataname=facenodes$face]
                            }
                            HmToolkit::Support lunique hole_entities
                        }
                        set washer 0
                    }
                    3 {
                        set type SquareTube

                        set size_top [lindex $h_info 2]
                        set size_buttom [lindex $h_info 9]
                        set size [expr ($size_top + $size_buttom) / 4]

                        set center_top [lindex $h_info 3]
                        set center_buttom [lindex $h_info 10]
                        set center [HmToolkit::Support Vector add $center_top $center_buttom]
                        set center [HmToolkit::Support Vector mul $center 0.5]

                        set axis_top [lindex $h_info 4]
                        set axis_buttom [lindex $h_info 11]
                        set axis [HmToolkit::Support Vector add $axis_top $axis_buttom]
                        set axis [HmToolkit::Support Vector mul $axis 0.5]

                        set entities_list [lindex $h_info 7]
                        set hole_entities nodes
                        if {[lindex $entities_list 0] eq "solids"} {
                            foreach {elem face} [lrange $entities_list 1 end] {
                                incr face
                                lappend hole_entities {*}[hm_getvalue elems id=$elem dataname=facenodes$face]
                            }
                            HmToolkit::Support lunique hole_entities
                        }
                        set washer 0
                    }
                    4 {
                        set type RectangularTube

                        set r1_top [lindex $h_info 2]
                        set r2_top [lindex $h_info 3]
                        set r_top [expr ($r1_top + $r2_top) / 2]
                        set r1_buttom [lindex $h_info 10]
                        set r2_buttom [lindex $h_info 11]
                        set r_buttom [expr ($r1_buttom  + $r2_buttom ) / 2]
                        set size [expr ($r_top + $r_buttom) / 4]

                        set center_top [lindex $h_info 4]
                        set center_buttom [lindex $h_info 11]
                        set center [HmToolkit::Support Vector add $center_top $center_buttom]
                        set center [HmToolkit::Support Vector mul $center 0.5]

                        set axis_top [lindex $h_info 5]
                        set axis_buttom [lindex $h_info 12]
                        set axis [HmToolkit::Support Vector add $axis_top $axis_buttom]
                        set axis [HmToolkit::Support Vector mul $axis 0.5]

                        set entities_list [lindex $h_info 7]
                        set hole_entities nodes
                        if {[lindex $entities_list 0] eq "solids"} {
                            foreach {elem face} [lrange $entities_list 1 end] {
                                incr face
                                lappend hole_entities {*}[hm_getvalue elems id=$elem dataname=facenodes$face]
                            }
                            HmToolkit::Support lunique hole_entities
                        }
                        set washer 0
                    }
                }
            }

            lappend res_infos [list $type $size $center $axis $hole_entities $washer]
        }

        hm_holedetectionend

        return $res_infos
    }

    proc adjacent_elems {elems {adj_num 1}} {
        set adjacent_elems $elems
        for {set i 0} {$i < $adj_num} {incr i} {
            *createmark elems 1 {*}$adjacent_elems
            *findmark elems 1 1 1 elements 0 2
            lappend adjacent_elems {*}[hm_getmark elems 2]
        }
        return $adjacent_elems
    }

    proc get_thickness_surf {surf {by_prop 0}} {
        if {$by_prop} {
            set comp [hm_getvalue surfs id=$surf dataname=collector]
            set thickness [hm_getvalue comps id=$comp dataname=thickness]
            if {$thickness > 0} {return $thickness}
        }
        set vertexs [HmToolkit::Query get_surf_vertexs $surf]
        set sum_thickness 0.0
        set n [llength $vertexs]
        foreach v $vertexs {
            set ret_v [hm_getsurfacethicknessvalues points $v]
            set thickness 0.0
            foreach value $ret_v {
                if {[lindex $value 0] == $surf} {set sum_thickness [expr $sum_thickness + [lindex $value 1]];break}
            }
        }
        return [expr $sum_thickness / $n]
    }

    proc iscurve {line} {
        set length [hm_getvalue lines id=$line dataname=length]
        set start [hm_getvalue lines id=$line dataname=startcoords]
        set end [hm_getvalue lines id=$line dataname=endcoords]
        set dist [get_dist $start $end]
        if {[expr $length - $dist] < 0.0001} {return 0} else {return 1}
    }

    proc iscurvesurf {surf} {
        *createmark surfs 1 $surf
        set centroid [hm_getcentroid surfs 1]

        set lines [hm_getvalue surfs id=$surf dataname=edges]
        foreach line $lines {
            if {[hm_getvalue line id=$line dataname=topologytype] eq "free" || [llength [hm_getsurfacesfromedge $line]] > 1} {
                break
            }
        }

        set coord1 [hm_getvalue line id=$line dataname=startcoords]
        set coord2 [hm_getvalue line id=$line dataname=endcoords]

        set v1 [lrange [hm_getsurfacenormalatcoordinate $surf {*}$centroid] 3 5]
        set v2 [lrange [hm_getsurfacenormalatcoordinate $surf {*}$coord1] 3 5]
        set v3 [lrange [hm_getsurfacenormalatcoordinate $surf {*}$coord2] 3 5]

        set c12 [HmToolkit::Support Vector cross $v1 $v2]
        set c13 [HmToolkit::Support Vector cross $v1 $v3]

        if {(abs([lindex $c12 0]) > 0.001 || abs([lindex $c12 1]) > 0.001 || abs([lindex $c12 2]) > 0.001)} {return 1}
        if {(abs([lindex $c13 0]) > 0.001 || abs([lindex $c13 1]) > 0.001 || abs([lindex $c13 2]) > 0.001)} {return 1}

        return 0
    }

    proc adjacent_edges {edge} {
        set vertexs [hm_getverticesfromedge $edge]
        set adj_edges {}
        foreach v $vertexs {
            lappend adj_edges {*}[hm_getedgesfromvertex $v]
        }
        HmToolkit::Support lunique adj_edges
        HmToolkit::Support lremove adj_edges $edge
        return $adj_edges
    }

    proc attach_entities {type entity_id} {

        *createmark $type 1 $entity_id
        *findmark $type 1 1 1 $type 0 2 1

        return [hm_getmark $type 2]
    }

    proc attach_groups {type entities_ids} {
        set attach_groups {}
        set i 0
        while {[llength $entities_ids]} {
            set s1 [lindex $entities_ids 0]
            set group $s1
            set attach_surfs [HmToolkit::Query attach_entities $type $s1]
            foreach s2 $entities_ids {
                if {$s2 in $attach_surfs} {
                    lappend group $s2
                }
            }
            HmToolkit::Support lremove entities_ids $group
            lappend attach_groups $group
            incr i
            if {$i > 1000} {
                break
            }
        }
        return $attach_groups
    }

    proc shortest_dist {type1 entities1 type2 entities2} {
        *createmark $type1 1 {*}$entities1
        *createmark $type2 2 {*}$entities2
        return [lindex [hm_measureshortestdistance $type1 1 0 $type2 2 0 0] 0]
    }

    namespace ensemble create
}
