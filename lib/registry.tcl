#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

package require snit

snit::type ::TclTaskRunner::TaskSetRegistry {
    option -root-dir
    option -task-extension .tcltask

    variable myDict [dict create]

    method all {} {set myDict}

    method get relName {
        dict get $myDict $relName
    }

    method resolve-spec {refSpec {from ""}} {
        # puts "resolve-spec $refSpec from $from"
        if {![regexp {^(@[^\#]+)(?:\#(.*))?} $refSpec -> file target]} {
            error "Invalid refSpec: $refSpec"
        }
        set ts [dict get $myDict $file]
        set actual [if {$target eq ""} {
            if {[set str [$ts cget -default]] eq ""} {
                error "Can't resolve refSpec '$refSpec'. No default target in taskset [$ts cget -name]"
            }
            set str
        } elseif {[$ts target exists $target]} {
            set target
        } else {
            error "No such target '$target' in taskset [$ts cget -name]"
        }]
        list $ts [$ts target kind $actual] $actual
    }

    method add {relName def} {
        dict set myDict $relName $def
    }

    method exists relName {
        dict exists $myDict $relName
    }

    method relative-name file {
        set fullFn [file rootname [file normalize $file]]
        set relFn [if {$options(-root-dir) eq ""} {
            set options(-root-dir) [file dirname $fullFn]/
            file tail $fullFn
        } elseif {[string equal -length [string length $options(-root-dir)] \
                      $options(-root-dir) $fullFn]} {
            string range $fullFn [string length $options(-root-dir)] end
        } else {
            error "Can't add a file from outside of -root-dir $options(-root-dir): $fullFn"
        }]

        return @[string map {/ ::} $relFn]
    }
}

if {![info level] && [info script] eq $::argv0} {
    ::TclTaskRunner::TaskSetRegistry reg
    puts [reg {*}$::argv]
}
