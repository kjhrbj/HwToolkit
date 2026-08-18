namespace eval ::HmToolkit {
    variable script_dir  [file dirname [info script]]
    variable lib_dir "$HmToolkit::script_dir/hm_lib/"
    variable contexts_dir "$HmToolkit::script_dir/contexts/"
    variable toolbar_dir "$HmToolkit::script_dir/toolbar/"

    variable debug 1
}

foreach lib [glob -directory "$HmToolkit::lib_dir" *.tcl] {
    puts "Source:$lib"
    source $lib
}

foreach script [glob -directory "$HmToolkit::toolbar_dir" *.tcl] {
    puts "Source:$script"
    source $script
}

foreach script [glob -directory "$HmToolkit::contexts_dir" *.tcl] {
    puts "run:$script"
    source $script
}