namespace eval ::HvToolkit {
    variable script_dir   [file dirname [info script]]
    variable lib_dir      "$HvToolkit::script_dir/hv_lib/"
    variable contexts_dir "$HvToolkit::script_dir/contexts/"
    variable toolbar_dir  "$HvToolkit::script_dir/toolbars/"

    variable debug 1

    proc debug {} {
        if {!$HvToolkit::debug} {return 0}
        foreach script [glob -directory "$HvToolkit::lib_dir" *.tcl] {
            puts "run:$script"
            source $script
        }
        foreach script [glob -directory "$HvToolkit::contexts_dir" *.tcl] {
            puts "run:$script"
            source $script
        }
    }
}

foreach lib [glob -directory "$HvToolkit::lib_dir" *.tcl] {
    puts "Source:$lib"
    source $lib
}

foreach script [glob -directory "$HvToolkit::toolbar_dir" *.tcl] {
    puts "Source:$script"
    source $script
}
