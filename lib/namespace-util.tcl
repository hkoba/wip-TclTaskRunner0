#!/usr/bin/env tclsh
# -*- coding: utf-8 -*-

#
# Extracted from sshcomm.tcl
#
namespace eval ::TclTaskRunner {

    proc ns-definition {ns args} {
        if {$ns eq ""} {
            set ns [namespace current]
        }
        array set seen {}
        set result {}
        foreach ns [list $ns {*}$args] {
            if {[info exists seen($ns)]} continue
            set seen($ns) 1
            foreach n [namespace-ancestry $ns] {
                append result [list namespace eval $n {}]\n
            }
            foreach pn [info procs [set ns]::*] {
                append result [definition-of-proc $pn]\n
            }
            foreach vn [info vars [set ns]::*] {
                if {![info exists $vn]} {
                    # really??
                    continue
                } elseif {[array exists $vn]} {
                    append result [list array set $vn [array get $vn]]\n
                } else {
                    append result [list set $vn [set $vn]]\n
                }
            }
            if {[llength [set pats [namespace eval $ns [list namespace export]]]]} {
                append result [list namespace eval $ns \
                                   [list namespace export {*}$pats]]\n
            }
            if {[namespace ensemble exists $ns]} {
                set ensemble [namespace ensemble configure $ns]
                dict unset ensemble -namespace
                # -parameters is not available in 8.5
                foreach drop [list -parameters] {
                    if {![dict exists $ensemble $drop]
                        || [dict get $ensemble $drop] ne ""} continue
                    dict unset ensemble $drop
                }
                append result [list namespace eval $ns \
                                   [list namespace ensemble create {*}$ensemble]]\n
            }
            foreach ns [namespace children $ns] {
                # puts "ns=$ns"
                append result [ns-definition $ns]\n
            }
        }
        set result
    }

    proc namespace-ancestry ns {
        set result {}
        while {$ns ne "" && $ns ne "::"} {
            set result [linsert $result 0 $ns]
            set ns [namespace parent $ns]
        }
        set result
    }
    
    proc definition-of-proc {proc} {
        set args {}
        foreach var [info args $proc] {
            if {[info default $proc $var default]} {
                lappend args [list $var $default]
            } else {
                lappend args $var
            }
        }
        list proc $proc $args [info body $proc]
    }
    
    proc definition-of-snit-macro {proc} {
        snit::Comp.Init

        set args {}
        foreach var [$::snit::compiler eval [list info args $proc]] {
            if {[$::snit::compiler eval [list info default $proc $var default]]} {
                lappend args [list $var $default]
            } else {
                lappend args $var
            }
        }
        list ::snit::macro $proc $args [$::snit::compiler eval [list info body $proc]]
    }
}
