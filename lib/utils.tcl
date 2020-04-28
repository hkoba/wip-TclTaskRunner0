# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

namespace eval ::TclTaskRunner {

    proc + {x y} {expr {$x + $y}}

    proc value value {set value}

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

    proc dict-cut {dictVar name {outVar ""}} {
        upvar 1 $dictVar dict
        if {$outVar eq ""} {set outVar $name}
        if {![dict exists $dict $name]} {
            return no
        }
            
        upvar 1 $outVar out
        set out [dict get $dict $name]
        dict unset dict $name
        return 1
    }

    proc scope_guard {varName command} {
        upvar 1 $varName var
        uplevel 1 [list trace add variable $varName unset \
                       [list apply [list args $command]]]
    }
    
    proc pushd_scope {varName newDir} {
        uplevel 1 [list scope_guard $varName [list cd [pwd]]]
        cd $newDir
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

    # proc re-matched {indices string {varName ""}} {
    #     lassign $indices first last
    #     if {$first == -1} {return no}
    #     if {$varName ne ""} {
    #         upvar 1 $varName match
    #     }
    #     set match [string range $string $first $last]
    #     if {$varName ne ""} {
    #         return yes
    #     } else {
    #         return $match
    #     }
    # }

    namespace export *
}
