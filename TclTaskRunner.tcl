#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

package require snit
package require fileutil

namespace eval TclTaskRunner {
    ::variable scriptFn [::fileutil::fullnormalize [info script]]
    ::variable scriptDir [file dirname $scriptFn]
    ::variable libDir [file join $scriptDir lib]
}

source $::TclTaskRunner::libDir/utils.tcl
source $::TclTaskRunner::libDir/iomacro.tcl

snit::type TclTaskRunner {
    component myRootTaskSet -public root

    variable myBuilder

    # XXX: dry-run
    option -debug
    option -quiet

    constructor args {
        install myRootTaskSet using TaskSetDefinition $self.main
        $self configurelist $args
        install myBuilder using TaskSetBuilder $self.builder \
            -toplevel $self -root $myRootTaskSet
    }

    method load {scriptFileName args} {
        $myBuilder taskset define file $scriptFileName \
             {*}$args -parent $myRootTaskSet
    }

    method define script {
        $myBuilder taskset define script $script \
            -parent $myRootTaskSet
    }
    
    method runner args {
        RunContext $self.runner.%AUTO% {*}$args \
            -root $myRootTaskSet -toplevel $self
    }
}

source $TclTaskRunner::libDir/builder.tcl
source $TclTaskRunner::libDir/context.tcl

snit::method TclTaskRunner usage args {
    return "Usage: [file tail $TclTaskRunner::scriptFn] ?main.tcltask?"
}

snit::typemethod TclTaskRunner toplevel args {
    set self ::dep
    $type $self -debug [default ::env(DEBUG) 0]\
        {*}[parsePosixOpts args]\

    if {[llength $args]} {
        set args [lassign $args taskFile]
    } else {
        set taskFile main.tcltask
    }

    $self configurelist [parsePosixOpts args]
    
    if {![file exists $taskFile]} {
        puts stderr [$self usage]
        exit 1
    }

    $self load $taskFile
    
    [$self runner] run
}

if {![info level] && [info script] eq $::argv0} {

    TclTaskRunner toplevel {*}$::argv

}
