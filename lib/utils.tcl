# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

namespace eval ::TclTaskRunner {
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
    
    proc dict-set-default {dictVar key default} {
        upvar 1 $dictVar dict
        if {![dict exists $dict $key]} {
            dict set dict $key $default
        }
    }

    proc dict-cut {dictVar name {default ""}} {
        upvar 1 $dictVar dict
        error nimpl
    }

    proc scope_guard {varName command} {
        upvar 1 $varName var
        uplevel 1 [list trace add variable $varName unset \
                       [list apply [list args $command]]]
    }
    
    proc parsePosixOpts {varName {dict {}}} {
        upvar 1 $varName opts

        for {} {[llength $opts]
                && [regexp {^--?([\w\-]+)(?:(=)(.*))?} [lindex $opts 0] \
                        -> name eq value]} {set opts [lrange $opts 1 end]} {
            if {$eq eq ""} {
                set value 1
            }
            dict set dict -$name $value
        }
        set dict
    }

    namespace export *
}
