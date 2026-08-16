if {[itcl::is class ::HmToolkit::CreateStepCtx]} { itcl::delete class ::HmToolkit::CreateStepCtx}

itcl::class ::HmToolkit::CreateStepCtx {
    inherit ::hm::context::HMScriptableBase
    constructor {args} {}

    public method proceed {args}
    public method ok {args}
    public method cancel {args}

    public method OnPost {args}
    public method OnUnpost {args}
    public method OnSelectionChange {args}
    public method AutoProceed {args}

    public method set_type {type}

    private method __perform {args}

    private variable __type Static
} 

itcl::body ::HmToolkit::CreateStepCtx::proceed {args} {
    ctx StartRecordHistory "Create Loadstep"
    if {[catch {__perform} error_info]} {
        ctx EndRecordHistory "Create Loadstep"
        ctx Undo
        Message "Function failed for unknown reason!\nerror info:$error_info"
    } else {ctx EndRecordHistory "Create Loadstep"}
    ctx::selection clear SPCSelector
    return 1
}

itcl::body ::HmToolkit::CreateStepCtx::ok {args} {
    if {[proceed]} {ctx::manager exit}
}

itcl::body ::HmToolkit::CreateStepCtx::cancel {args} {
    ctx::manager exit
}

itcl::body ::HmToolkit::CreateStepCtx::OnPost {args} {
    ctx::ui post pp
}

itcl::body ::HmToolkit::CreateStepCtx::OnUnpost {args} {

}

itcl::body ::HmToolkit::CreateStepCtx::OnSelectionChange {args} {

}

itcl::body ::HmToolkit::CreateStepCtx::AutoProceed {args} {
    proceed
}

itcl::body ::HmToolkit::CreateStepCtx::set_type {type} {
    ctx::ui set type_chooser -label $type
    ctx::ui post pp
    switch $type {
        Static {
            set __type Static
            ctx::ui set set_start -visible 0
            ctx::ui set set_end -visible 0
            ctx::ui set set_G -visible 0
            ctx::ui set set_damp -visible 0
            ctx::ui set set_nd -visible 0

            ctx::ui set set_gravx -visible 1
            ctx::ui set set_gravy -visible 1
            ctx::ui set set_gravz -visible 1
        }
        Mode {
            set __type Mode
            ctx::ui set set_gravx -visible 0
            ctx::ui set set_gravy -visible 0
            ctx::ui set set_gravz -visible 0
            ctx::ui set set_G -visible 0
            ctx::ui set set_damp -visible 0


            ctx::ui set set_start -visible 1
            ctx::ui set set_end -visible 1
            ctx::ui set set_nd -visible 1
        }
        FreqResp {
            set __type FreqResp
            ctx::ui set set_gravx -visible 0
            ctx::ui set set_gravy -visible 0
            ctx::ui set set_gravz -visible 0
            ctx::ui set set_nd -visible 0

            ctx::ui set set_start -visible 1
            ctx::ui set set_end -visible 1
            ctx::ui set set_G -visible 1
            ctx::ui set set_damp -visible 1
        }
        Random {
            # todo
        }
        default {}
    }
}

itcl::body ::HmToolkit::CreateStepCtx::__perform {args} {
    set prefix [ctx GetOption prefix]
    set SPC_elems [ctx::selection ids SPCSelector]
    switch $__type {
        Static {
            set gx [ctx GetOption gx]
            set gy [ctx GetOption gy]
            set gz [ctx GetOption gz]

            set loadstep_x [HmToolkit::Modify Create loadstep "$prefix\Static_X_$gx\g" $__type]
            set loadstep_y [HmToolkit::Modify Create loadstep "$prefix\Static_Y_$gy\g" $__type]
            set loadstep_z [HmToolkit::Modify Create loadstep "$prefix\Static_Z_$gz\g" $__type]

            if {![set SPCid [HmToolkit::Query exist loadcol name=SPC]]} {set SPCid [HmToolkit::Modify Create loadcol SPC]}

            if {[llength $SPC_elems]} {
                set SPC_nodes {}
                foreach elem $SPC_elems {
                if {[hm_getvalue elems id=$elem dataname=config] == 55} {
                    lappend SPC_nodes [hm_getvalue elems id=$elem dataname=independentnode]
                    continue
                }
                lappend SPC_nodes {*}[hm_getvalue elems id=$elem dataname=nodes]
                }
                if {[llength $SPC_nodes]} {
                    *currentcollector loadcol SPC
                    *createmark nodes 1 {*}$SPC_nodes
                    *loadcreate 1 3 1 0 0 0 0 0 0
                }
            }

            set loadx [HmToolkit::Modify Create grav "$prefix\X_$gx\g" [expr $gx * 9800] "[expr $gx / abs($gx)] 0 0"]
            set loady [HmToolkit::Modify Create grav "$prefix\Y_$gy\g" [expr $gy * 9800] "0 [expr $gx / abs($gx)] 0"]
            set loadz [HmToolkit::Modify Create grav "$prefix\Z_$gz\g" [expr $gz * 9800] "0 0 [expr $gx / abs($gx)]"]

            HmToolkit::Modify set_loadstep $loadstep_x -SPC $SPCid -load $loadx
            HmToolkit::Modify set_loadstep $loadstep_y -SPC $SPCid -load $loady
            HmToolkit::Modify set_loadstep $loadstep_z -SPC $SPCid -load $loadz
        }
        Mode {
            set SPC_nodes {}
            if {[llength $SPC_elems]} {
                foreach elem $SPC_elems {
                if {[hm_getvalue elems id=$elem dataname=config] == 55} {
                    lappend SPC_nodes [hm_getvalue elems id=$elem dataname=independentnode]
                    continue
                }
                lappend SPC_nodes {*}[hm_getvalue elems id=$elem dataname=nodes]
                }
            }

            set loadstepid [HmToolkit::Modify Create loadstep "$prefix\Mode" $__type]

            if {![set SPCid [HmToolkit::Query exist loadcol name=SPC]]} {
                set SPCid [HmToolkit::Modify Create loadcol SPC]
                if {[llength $SPC_nodes]} {
                    *currentcollector loadcol SPC
                    *createmark nodes 1 {*}$SPC_nodes
                    *loadcreate 1 3 1 0 0 0 0 0 0
                }
            }

            set v1 [ctx GetOption start]
            set v2 [ctx GetOption end]
            set nd [ctx GetOption nd]

            set eigen [HmToolkit::Modify Create eigen "$prefix\Eigen_Mode" $v1 $v2 $nd]

            HmToolkit::Modify set_loadstep $loadstepid -SPC $SPCid -eigen $eigen
        }
        FreqResp {
            set SPC_nodes {}
            if {[llength $SPC_elems]} {
                foreach elem $SPC_elems {
                if {[hm_getvalue elems id=$elem dataname=config] == 55} {
                    lappend SPC_nodes [hm_getvalue elems id=$elem dataname=independentnode]
                    continue
                }
                lappend SPC_nodes {*}[hm_getvalue elems id=$elem dataname=nodes]
                }
            }

            # set loadstep_mode [HmToolkit::Modify Create loadstep "$prefix\Mode" Mode]
            set loadstep_x [HmToolkit::Modify Create loadstep "$prefix\FreqResp_X" $__type]
            set loadstep_y [HmToolkit::Modify Create loadstep "$prefix\FreqResp_Y" $__type]
            set loadstep_z [HmToolkit::Modify Create loadstep "$prefix\FreqResp_Z" $__type]

            if {![set SPCid [HmToolkit::Query exist loadcol name=SPC]]} {
                set SPCid [HmToolkit::Modify Create loadcol SPC]
                if {[llength $SPC_nodes]} {
                    *currentcollector loadcol SPC
                    *createmark nodes 1 {*}$SPC_nodes
                    *loadcreate 1 3 1 0 0 0 0 0 0
                }
            }

            set start [ctx GetOption start]
            set end [ctx GetOption end]
            set g [ctx GetOption g]
            set damp [ctx GetOption damp]

            set freqi [HmToolkit::Modify Create freqi "$prefix\Freqi" $start 1 [expr $end - $start]]
            set damp [HmToolkit::Modify Create damp "$prefix\Damp" $damp]
            set eigen_v2 [expr 2 * $end]
            set eigen [HmToolkit::Modify Create eigen "$prefix\Eigen" 0 $eigen_v2]

            # HmToolkit::Modify set_loadstep $loadstep_mode -SPC $SPCid -eigen $eigen

            set dload_x [HmToolkit::Modify Create dload "$prefix\Dload_X" [expr 9800 * $g] $SPC_nodes "1 -999999 -999999 -999999 -999999 -999999"]
            set dload_y [HmToolkit::Modify Create dload "$prefix\Dload_Y" [expr 9800 * $g] $SPC_nodes "-999999 1 -999999 -999999 -999999 -999999"]
            set dload_z [HmToolkit::Modify Create dload "$prefix\Dload_Z" [expr 9800 * $g] $SPC_nodes "-999999 -999999 1 -999999 -999999 -999999"]

            foreach {loadstepid dload} "$loadstep_x $dload_x $loadstep_y $dload_y $loadstep_z $dload_z" {
                HmToolkit::Modify set_loadstep $loadstepid -SPC $SPCid -freqi $freqi -damp $damp -dload $dload -eigen $eigen
                # set output
                *setvalue loadsteps id=$loadstepid STATUS=2 351=1
                # set output_disp
                *setvalue loadsteps id=$loadstepid STATUS=2 2938=1
                *setvalue loadsteps id=$loadstepid STATUS=0 1901=1
                *setvalue loadsteps id=$loadstepid STATUS=0 11314={analysisparameters 0}
                *setvalue loadsteps id=$loadstepid STATUS=2 ROW=0 2939= {ALL}
                # set output_stress
                *setvalue loadsteps id=$loadstepid STATUS=2 2431=1
                *setvalue loadsteps id=$loadstepid STATUS=0 1923=2
                *setvalue loadsteps id=$loadstepid STATUS=0 11312={analysisparameters 0}
                *setvalue loadsteps id=$loadstepid STATUS=2 ROW=0 2432= {YES}
                *setvalue loadsteps id=$loadstepid STATUS=2 ROW=1 2432= {YES}
                *setvalue loadsteps id=$loadstepid STATUS=2 ROW=0 4325= {H3D}
                *setvalue loadsteps id=$loadstepid STATUS=2 ROW=1 4325= {OP2}
            }
        }
        default {}
    }

    hm_usermessage "Loadstep created successfully."

    return 1
}

ctx::manager register hm CreateStepCtx "::HmToolkit::CreateStepCtx"
puts "register: HmToolkit::CreateStepCtx"