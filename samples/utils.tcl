#!/usr/bin/tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

# $self import thisFile

proc lines-of args {
    split [uplevel 1 $args] \n
}

proc unindent text {
    # [string cat] requires 8.6
    join [list [string trim [if {[regexp {^\n[\ \t]*} $text indent]} {
        puts stderr "# trimming indent($indent)"
        string map [list $indent "\n"] $text
    } else {
        string map [list "\n    " "\n" "\n\t" "\n    "] $text
    }]] "\n"] ""
}

proc default {varName {default ""}} {
    upvar 1 $varName var
    if {[info exists var]} {
        set var
    } else {
        set default
    }
}

proc dict-default {dict key {default ""}} {
    if {[dict exists $dict $key]} {
        dict get $dict $key
    } else {
        set default
    }
}

proc dict-cut {dictVar key args} {
    upvar 1 $dictVar dict
    if {[dict exists $dict $key]} {
        set res [dict get $dict $key]
        dict unset dict $key
        set res
    } elseif {[llength $args]} {
        lindex $args 0
    } else {
        error "No such key: $key"
    }
    
}

# dictA - (dictB items which found in dictA too)
# (useful to check [file attributes] difference)
proc dict-left-difference {dictA dictB} {
    set difference {}
    foreach key [dict keys $dictA] {
        if {[set val [dict get $dictA $key]] ne [dict get $dictB $key]} {
            lappend difference $key $val
        }
    }
    set difference
}

proc dict-compare {dictA dictB} {
    set diffA {}
    set diffB {}
    foreach k [dict keys $dictA] {
        if {![dict exists $dictB $k]
            || [dict get $dictB $k] ne [dict get $dictA $k]} {
            dict set diffA $k [dict get $dictA $k]
        }
    }
    foreach k [dict keys $dictB] {
        if {![dict exists $dictA $k]
            || [dict get $dictA $k] ne [dict get $dictB $k]} {
            dict set diffB $k [dict get $dictB $k]
        }
    }
    if {$diffA eq "" && $diffB eq ""} {
        return ""
    } else {
        list $diffA $diffB
    }
}

proc is-empty str {
    expr {$str eq ""}
}

proc lgrep {pattern list {cmdOrArgs ""} {apply ""}} {
    set res {}
    if {$cmdOrArgs eq "" && $apply eq ""} {
        foreach i $list {
            if {![regexp $pattern $i]} continue
            lappend res $i
        }
    } else {
        set cmd [if {$apply ne ""} {
            list apply [list $cmdOrArgs $apply]
        } else {
            list $cmdOrArgs
        }]
        foreach i $list {
            if {![llength [set m [regexp -inline $pattern $i]]]} continue
            lappend res [{*}$cmd {*}$m]
        }
    }
    set res
}

proc lsearch-and-get {list value {offset 0}} {
    set mypos [lsearch $list $value]
    if {$mypos < 0} {
        error "No such value: $value"
    }
    lindex $list [expr {$mypos + $offset}]
}

proc file-has {pattern fn args} {
    llength [filelist-having $pattern $fn {*}$args]
}

proc filelist-having {pattern fn args} {
    set found {}
    foreach fn [linsert $args 0 $fn] {
        set fh [open $fn]
        scope_guard fh [list close $fh]
        for-chan-line line $fh {
            if {![regexp $pattern $line]} continue
            lappend found $fn
            break
        }
        unset fh
    }
    set found
}

proc for-chan-line {lineVar chan command} {
    upvar $lineVar line
    while {[gets $chan line] >= 0} {
        uplevel 1 $command
    }
}

proc read_file {fn args} {
    set fh [open $fn]
    scope_guard fh [list close $fh]
    if {[llength $args]} {
        fconfigure $fh {*}$args
    }
    read $fh
}

proc read_file_lines {fn args} {
    set fh [open $fn]
    scope_guard fh [list close $fh]
    if {[llength $args]} {
        fconfigure $fh {*}$args
    }
    set lines {}
    while {[gets $fh line] >= 0} {
        lappend lines $line
    }
    set lines
}

proc read_shell_env_file fn {
    set fh [open $fn]
    scope_guard fh [list close $fh]
    set dict [dict create]
    while {[gets $fh line] >= 0} {
        if {[regexp ^\# $line]} continue
        if {![regexp {^(\w+)=(.*)} $line -> key value]} continue
        dict set dict $key $value
    }
    set dict
}

proc subst_shell_env_file {fn key args} {
    if {[llength $args]} {
        set dict [dict create $key {*}$args]
        set drop no
    } else {
        set dict [dict create $key ""]
        set drop yes
    }
    set fh [open $fn]
    scope_guard fh [list close $fh]
    set result []
    while {[gets $fh line] >= 0} {
        if {![regexp ^\# $line]
            && [regexp {^(\w+)=(.*)} $line -> k v]
            && [dict exists $dict $k]
        } {
            if {$drop} {
                continue
            } else {
                append result $k=[dict get $dict $k]\n
            }
        } else {
            append result $line\n
        }
    }
    set result
}

proc shell-quote-string string {
    # XXX: Is this enough for /bin/sh's "...string..." quoting?
    # $
    # backslash
    # `
    # "
    # !
    regsub -all {[$\\`\"!]} $string {\\&}
}

proc text-of-list-of-list {ll {sep " "} {eos "\n"}} {
    set list {}
    foreach i $ll {
        lappend list [join $i $sep]
    }
    return [join $list \n]$eos
}

proc append_file {fn data args} {
    write_file $fn $data {*}$args -access a
}

proc write_file_lines {fn list args} {
    write_file $fn [join $list \n] {*}$args
}

proc write_file {fn data args} {
    set data [string trim $data]
    regsub {\n*\Z} $data \n data
    write_file_raw $fn $data {*}$args
}

proc write_file_raw {fn data args} {
    set access [dict-cut args -access w]
    if {![regexp {^[wa]} $access]} {
        error "Invalid access flag to write_file $fn: $access"
    }
    set attlist {}
    set rest {}
    if {[set perm [dict-cut args -permissions ""]] ne ""} {
        if {[string is integer $perm]} {
            lappend rest $perm
        } else {
            lappend attlist -permissions $perm
        }
    }
    foreach att [list -group -owner] {
        if {[set val [dict-cut args $att ""]] ne ""} {
            lappend attlist $att $val
        }
    }
    set fh [open $fn $access {*}$rest]
    if {$attlist ne ""} {
        file attributes $fn {*}$attlist
    }
    scope_guard fh [list close $fh]
    if {[llength $args]} {
        fconfigure $fh {*}$args
    }
    puts -nonewline $fh $data
    set fn
}

proc scope_guard {varName command} {
    upvar 1 $varName var
    uplevel 1 [list trace add variable $varName unset \
                   [list apply [list args $command]]]
}

proc catch-exec args {
    set rc [catch [list exec {*}$args] result]
    set result
}

proc catch-exec-noerror args {
    set rc [catch [list exec {*}$args] result]
    expr {! $rc}
}

namespace export *
