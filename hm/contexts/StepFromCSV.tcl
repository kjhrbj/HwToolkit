if {[itcl::is class ::HmToolkit::StepFromCSVCtx]} { itcl::delete class ::HmToolkit::StepFromCSVCtx}

itcl::class ::HmToolkit::StepFromCSVCtx {
    inherit ::hm::context::HMScriptableBase
    constructor {args} {}

    public method proceed {args}
    public method ok {args}
    public method cancel {args}

    public method OnPost {args}
    public method OnUnpost {args}
    public method OnSelectionChange {args}
    public method AutoProceed {args}

    public method get_CSV {args}

    private method __perform {args}
    private variable csv_file_path ""
}

itcl::body ::HmToolkit::StepFromCSVCtx::proceed {args} {
    if {$csv_file_path eq ""} {
        Message "Please choose the csv file!"
        return 0
    }
    if {[catch {__perform} error_info]} {
        Message "Function failed for unknown reason!\nerror info:$error_info"
        return 0
    } else {
        return 1
    }
}

itcl::body ::HmToolkit::StepFromCSVCtx::ok {args} {
    if {[proceed]} {ctx::manager exit}
}

itcl::body ::HmToolkit::StepFromCSVCtx::cancel {args} {
    ctx::manager exit
}

itcl::body ::HmToolkit::StepFromCSVCtx::OnPost {args} {
    ctx SetOption prefix ""
    set current_file [hm_info currentfile]

    if {$current_file ne ""} {
        set filename [file rootname [file tail $current_file]]

        if {[regexp {(.*)-([\d]*-[\d]*)} $filename -> basename]} {
            ctx SetOption prefix $basename
        } else {
            ctx SetOption prefix $filename
        }
    }

    ctx::ui post pp
}

itcl::body ::HmToolkit::StepFromCSVCtx::OnUnpost {args} {

}

itcl::body ::HmToolkit::StepFromCSVCtx::OnSelectionChange {args} {

}

itcl::body ::HmToolkit::StepFromCSVCtx::AutoProceed {args} {
    proceed
}

itcl::body ::HmToolkit::StepFromCSVCtx::get_CSV {args} {
    set csv_file_path [tk_getOpenFile -title "选择一个CSV文件" \
        -filetypes {{"CSV file" {.csv}}}]
}

itcl::body ::HmToolkit::StepFromCSVCtx::__perform {args} {
    set csv [open $csv_file_path r]

    if {[gets $csv line] < 0} {return 0}
    set SPCsetid [lindex [split $line ","] 1]

    *createentity loadcol name=SPC
    set SPCid [HmToolkit::Support currentids loadcol 1]
    
    if {$SPCsetid ne 0} {
        *createmark sets 1 $SPCsetid
        *loadcreateonentity_curve sets 1 3 1 0 0 0 0 0 0 0 0 0 0 0
    }

    if {[gets $csv line] < 0} {return 0}
    set set_ids [lrange [split $line ","] 1 end]
    HmToolkit::Support lremove set_ids "{}"
    set n [llength $set_ids]

    if {[gets $csv line] < 0} {return 0}
    while {[gets $csv line] >= 0} {
        set fields [split $line ","]
        set fields_length [llength $fields]

        if {[expr $fields_length - 1 - ($n * 3)] ne 3} {
            Message "The number of sets is not match to the number of loads"
            return 0
        }
        set load_step_name [lindex $fields 0]

        *createentity loadsteps name=$load_step_name
        set loadstepid [HmToolkit::Support currentids loadsteps 1]
        *setvalue loadsteps id=$loadstepid STATUS=1 4709=1
        *setvalue loadsteps id=$loadstepid STATUS=2 4059=1
        *setvalue loadsteps id=$loadstepid STATUS=2 4060=STATICS
        *setvalue loadsteps id=$loadstepid STATUS=2 3451=0
        *setvalue loadsteps id=$loadstepid STATUS=2 4152=0

        *createentity loadcol name=$load_step_name-loads
        set loadcol [HmToolkit::Support currentids loadcol 1]
        for {set i 0} {$i < $n} {incr i} {
            *createmark sets 1 [lindex $set_ids $i]
            set fx [lindex $fields [expr $i * 3 + 1]]
            set fy [lindex $fields [expr $i * 3 + 2]]
            set fz [lindex $fields [expr $i * 3 + 3]]
            *createmark sets 1 [lindex $set_ids $i]
            *loadcreateonentity_curve sets 1 1 1 $fx $fy $fz 0 0 1 0 0 0 0 0
        }
        set loads $loadcol
        set gx [lindex $fields [expr $i * 3 + 1]]
        if {$gx ne 0} {
            *createentity loadcol name=$load_step_name-GX
            set grav [HmToolkit::Support currentids loadcol 1]
            *setvalue loadcols id=$grav cardimage="GRAV"
            *setvalue loadcols id=$grav STATUS=2 2899=$gx
            *setvalue loadcols id=$grav STATUS=2 2900=1
            *setvalue loadcols id=$grav STATUS=2 2901=0
            *setvalue loadcols id=$grav STATUS=2 2902=0
            lappend loads $grav
        }
        set gy [lindex $fields [expr $i * 3 + 2]]
        if {$gy ne 0} {
            *createentity loadcol name=$load_step_name-GY
            set grav [HmToolkit::Support currentids loadcol 1]
            *setvalue loadcols id=$grav cardimage="GRAV"
            *setvalue loadcols id=$grav STATUS=2 2899=$gy
            *setvalue loadcols id=$grav STATUS=2 2900=1
            *setvalue loadcols id=$grav STATUS=2 2901=0
            *setvalue loadcols id=$grav STATUS=2 2902=0
            lappend loads $grav
        }
        set gz [lindex $fields [expr $i * 3 + 3]]
        if {$gz ne 0} {
            *createentity loadcol name=$load_step_name-GZ
            set grav [HmToolkit::Support currentids loadcol 1]
            *setvalue loadcols id=$grav cardimage="GRAV"
            *setvalue loadcols id=$grav STATUS=2 2899=$gz
            *setvalue loadcols id=$grav STATUS=2 2900=1
            *setvalue loadcols id=$grav STATUS=2 2901=0
            *setvalue loadcols id=$grav STATUS=2 2902=0
            lappend loads $grav
        }

        *createentity loadcols cardimage=LOADADD includeid=0 name=$load_step_name-LoadAdd
        set loadaddid [HmToolkit::Support currentids loadcols 1]
        set load_num [expr [llength $loads]]
        set c {}
        for {set i 0} {$i < $load_num} {incr i} {
            lappend c 1
        }
        set loads "loadcols $loads"
        *setvalue loadcols id=$loadaddid STATUS=2 3236=$load_num
        *setvalue loadcols id=$loadaddid STATUS=2 380=$c
        *setvalue loadcols id=$loadaddid STATUS=2 383=$loads

        set ids {}
        *setvalue loadsteps id=$loadstepid STATUS=2 OS_SPCID={loadcols $SPCid}
        *setvalue loadsteps id=$loadstepid STATUS=2 4143=1
        *setvalue loadsteps id=$loadstepid STATUS=1 4144=1
        *setvalue loadsteps id=$loadstepid STATUS=1 4145={Loadcols $SPCid}
        lappend ids $SPCid
        *setvalue loadsteps id=$loadstepid STATUS=2 OS_LOADID={loadcols $loadaddid}
        *setvalue loadsteps id=$loadstepid STATUS=2 4143=1
        *setvalue loadsteps id=$loadstepid STATUS=1 4146=1
        *setvalue loadsteps id=$loadstepid STATUS=1 4147={Loadcols $loadaddid}
        *setvalue loadsteps id=$loadstepid STATUS=0 7763=0
        *setvalue loadsteps id=$loadstepid STATUS=1 7740={Loadcols 0}
        lappend ids $loadaddid
        *setvalue loadsteps id=$loadstepid STATUS=2 ids=$ids
    }

}

ctx::manager register hm StepFromCSVCtx "::HmToolkit::StepFromCSVCtx"
puts "register: HmToolkit::StepFromCSVCtx"