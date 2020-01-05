#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

package require snit

snit::macro ::TclTaskRunner::use_logging {{quiet no}} {
    option -quiet $quiet
    option -log-fh stdout
    option -log-prefix "# "
    option -debug 0
    option -debug-fh stdout
    option -indent "  "
    
    method dputs {depth args} {$self dputsLevel 1 $depth {*}$args}
    method dputsLevel {level depth args} {
        if {$options(-debug) < $level} return
        set indent [string repeat $options(-indent) $depth]
        set lineList [split $args \n]
        foreach line $lineList {
            puts $options(-debug-fh) "$indent#| $line"
        }
        if {[llength $lineList] >= 2} {
            puts $options(-debug-fh) "$indent#|"
        }
    }
}
