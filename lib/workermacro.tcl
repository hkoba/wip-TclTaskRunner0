#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

package require snit

snit::macro ::TclTaskRunner::use_worker {} {
    option -isolate yes

    variable myWorker ""
    option -worker
    onconfigure -worker worker {
        install myWorker using set worker
    }

    method {worker init} {} {
        if {$myWorker eq ""} {
            if {$options(-isolate)} {
                install myWorker using list [interp create $self.worker] eval
            } else {
                install myWorker using list interp eval {}
            }
        }
    }
    
    method {worker call} args {
        {*}$myWorker $args
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
        } else {
            foreach ns [$ourTaskSetType instance namespaces] {
                # Definition should be updated always.
                set script [TclTaskRunner::ns-definition $ns]
                if {$options(-debug) >= 3} {
                    puts \#[list sync runtime type $ns $script]
                }
                {*}$myWorker $script
                
                # Instance should be created only if it is missing.
                if {[{*}$myWorker [list info commands ${ns}::instance]] eq ""} {
                    {*}$myWorker [list ${ns}::runtime create ${ns}::instance]
                }
            }
        }
        # puts stderr \#[list runtime has [{*}$myWorker info commands ::TclTaskRunner::TaskSetDefinition::Snit_inst1::instance]]
    }

    method {worker steal} {cmd args} {
        if {$options(-isolate)} {
            lassign $myWorker interp
            foreach cmd [list $cmd {*}$args] {
                $interp alias puts puts
            }
        }
    }
}
