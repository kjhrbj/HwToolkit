namespace eval ::HvToolkit {
    variable script_dir   [file dirname [info script]]
    variable lib_dir      "$HvToolkit::script_dir/hv_lib/"
    variable scripts_dir  "$HvToolkit::script_dir/scripts/"

    variable debug 1
    
}

foreach lib [glob -directory "$HvToolkit::lib_dir" *.tcl] {
    puts "Source:$lib"
    source $lib
}

foreach script [glob -directory "$HvToolkit::scripts_dir" *.tcl] {
    puts "Source:$script"
    source $script
}
