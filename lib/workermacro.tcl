#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

package require snit

snit::macro ::TclTaskRunner::use_worker {} {
    option -isolate yes

    option -dry-run-marker **

    variable myWorker ""
    variable myInterp ""
    method {worker init} {} {
        if {$options(-isolate)} {
            install myInterp using interp create $self.worker
            install myWorker using list $myInterp eval
        } else {
            install myWorker using list interp eval $myInterp
        }
    }
    
    method {worker call} args {
        if {$options(-debug) >= 3} {
            foreach line [split $args \n] {
                $self dputsRaw "# $line"
            }
        }
        {*}$myWorker $args
    }

    method {worker do} script {
        if {$options(-debug) >= 3} {
            foreach line [split $script \n] {
                $self dputsRaw "# $line"
            }
        }
        {*}$myWorker $script
    }

    method {worker sync} {} {
        if {[{*}$myWorker [list info commands ::snit::type]] eq ""} {
            {*}$myWorker [list package require snit]
        }
        if {[{*}$myWorker [list info commands $type]] eq ""} {
            set script [TclTaskRunner::ns-definition ::TclTaskRunner]
            if {$options(-debug) >= 3} {
                puts \#[list sync type $script]
            }
            {*}$myWorker $script
        }
        foreach {name pkgSpec} [$self registry package loaded] {
            {*}$myWorker [list package require $name {*}$pkgSpec]
        }
        foreach def [dict values [$self registry all]] {
            foreach ns [$def import ns-list] {
                {*}$myWorker [TclTaskRunner::ns-definition $ns]
            }
            {*}$myWorker [list uplevel #0 [$myBuilder taskset genscript $def]]
        }

        interp alias $myInterp $options(-dry-run-marker) \
            {} $self worker traced
    }

    method {worker traced} args {
        if {! $options(-silent)} {
            puts $options(-log-fh) $args
        }
        if {$options(-dry-run)} return
        interp eval $myInterp $args
    }

    method {worker steal} {cmd args} {
        if {$options(-isolate)} {
            foreach cmd [list $cmd {*}$args] {
                $myInterp alias puts puts
            }
        }
    }
}
