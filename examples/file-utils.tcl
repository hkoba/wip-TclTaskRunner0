# -*- coding: utf-8 -*-

namespace eval file-utils {

    proc check-dir-spec {dir want {diffOnly ""}} {
	if {![file exists $dir]} {
	    return 0
	}
	if {![file isdirectory $dir]} {
	    return [list 0 "Can't mkdir for existing file: $dir"]
	}
	set got [file attributes $dir]
	set diff {}
	foreach k {-owner -group} {
	    if {![dict exists $want $k]
		|| [dict get $got $k] eq [dict get $want $k]} continue
	    lappend diff $k [dict get $want $k]
	}
	set k -permissions
	if {[dict get $got $k] != [dict get $want $k]} {
	    lappend diff $k [dict get $want $k]
	}

        if {$diffOnly ne ""} {
            set diff
        } else {
            list [expr {[llength $diff] == 0}] {*}$diff
        }
    }
    
    proc check-file-spec {file want {diffOnly ""}} {
	if {![file exists $file]} {
	    return 0
	}
	set got [file attributes $file]
	set diff {}
	foreach k {-owner -group} {
	    if {![dict exists $want $k]
		|| [dict get $got $k] eq [dict get $want $k]} continue
	    lappend diff $k [dict get $want $k]
	}
	set k -permissions
	if {[dict get $got $k] != [dict get $want $k]} {
	    lappend diff $k [dict get $want $k]
	}

        if {$diffOnly ne ""} {
            set diff
        } else {
            list [expr {[llength $diff] == 0}] {*}$diff
        }
    }

    proc apply-dir-spec {dir spec {resVar ""}} {
        if {$resVar ne ""} {
            upvar 1 $resVar res
        }
        if {![file exists $dir]} {
            file mkdir $dir
            set res [check-dir-spec $dir $spec]
        }
        set diff [lassign $res -]
        file attributes $dir {*}$diff
    }

    namespace export *
    
    namespace current;  # This is important for [import * from file] from *.tcltask
}
