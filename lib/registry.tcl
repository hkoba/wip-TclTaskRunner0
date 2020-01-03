#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

package require snit

snit::type ::TclTaskRunner::TaskSetRegistry {
    option -root-dir
    option -task-extension .tcltask

    variable myDict

    method intern file {
        set fullFn [file rootname [file normalize $file]]
        if {$options(-root-dir) eq ""} {
            set options(-root-dir) [file dirname $fullFn]
            file tail $fullFn
        } elseif {[string equal -length [string length $options(-root-dir)] \
                      $options(-root-dir) [file dirname $fullFn]]} {
            string range $fullFn [string length $options(-root-dir)]
        } else {
            error "Can't add a file from outside of -root-dir $options(-root-dir): $fullFn"
        }
    }
}

if {![info level] && [info script] eq $::argv0} {
    ::TclTaskRunner::TaskSetRegistry reg
    puts [reg {*}$::argv]
}
