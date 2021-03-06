#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

package require snit
package require fileutil

snit::type ::TclTaskRunner::TaskSetRegistry {
    option -root-dir
    option -task-extension .tcltask
    
    variable myDict [dict create]
    variable myPackageDict [dict create]

    typevariable ourUseSpecRe {^@|\.tcltask$}

    method all {} {set myDict}

    method get relName {
        dict get $myDict $relName
    }

    method exists relName {
        dict exists $myDict $relName
    }

    method parse-use-spec {useSpec {rootNameVar ""}} {
        if {$rootNameVar ne ""} {
            upvar 1 $rootNameVar rootName
        }
        set rc [regsub $ourUseSpecRe $useSpec {} rootName]
        if {$rootNameVar ne ""} {
            return $rc
        } elseif {!$rc} {
            error "Invalid use spec: $useSpec"
        } else {
            return @$rootName
        }
    }

    method parse-extern {refSpec relFileVar targetVar} {
        upvar 1 $relFileVar relFile
        upvar 1 $targetVar target
        regexp {^(@[^\#]+)(?:\#(.*))?} $refSpec -> relFile target
    }

    method resolve-spec {refSpec {from ""}} {
        # puts "resolve-spec $refSpec from $from"
        if {![$self parse-extern $refSpec file target]} {
            error "Invalid refSpec: $refSpec"
        }
        set ts [dict get $myDict $file]
        set actual [if {[default target ""] eq ""} {
            if {[set str [$ts cget -default]] eq ""} {
                error "Can't resolve refSpec '$refSpec'. \
                No default target in taskset [$ts cget -name]"
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

    method relative-filename file {
        set fullFn [fileutil::lexnormalize [file normalize $file]]
        if {$options(-root-dir) eq ""} {
            set options(-root-dir) [file dirname $fullFn]/
            file tail $fullFn
        } elseif {[string equal -length [string length $options(-root-dir)] \
                      $options(-root-dir) $fullFn]} {
            string range $fullFn [string length $options(-root-dir)] end
        } else {
            error "Can't add a file from outside of\
             -root-dir $options(-root-dir): $fullFn, orig=$file"
        }
    }
    
    method relative-name file {
        set relFn [file rootname [$self relative-filename $file]]
        return @[string map {/ ::} $relFn]
    }
    
    method {package require} {name args} {
        if {[dict exists $myPackageDict $name]
            && $args ne ""
            && [package vsatisfies [dict get $myPackageDict $name] {*}$args]} {
            return [dict get $myPackageDict $name]
        }
        dict set myPackageDict $name \
            [package require $name {*}$args]
    }
    method {package loaded} {} {
        set myPackageDict
    }
    
}

if {![info level] && [info script] eq $::argv0} {
    ::TclTaskRunner::TaskSetRegistry reg
    puts [reg {*}$::argv]
}
