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
source $::TclTaskRunner::libDir/typemacro.tcl
source $::TclTaskRunner::libDir/logmacro.tcl
source $::TclTaskRunner::libDir/tasksetdef.tcl

snit::type TclTaskRunner {
    component myTaskSetRegistry -public registry

    variable myBuilder

    option -dry-run no
    ::TclTaskRunner::use_logging

    constructor args {
        install myTaskSetRegistry using TaskSetRegistry $self.registry
        $self configurelist $args
        install myBuilder using TaskSetBuilder $self.builder \
            -toplevel $self -registry $myTaskSetRegistry \
            -debug $options(-debug)
    }

    method use scriptFileName {
        $myBuilder taskset ensure-loaded $scriptFileName
    }

    method define script {
        error NIMPL
        $myBuilder taskset define script $script \
            -parent $myRootTaskSet
    }
    
    method run args {
        set runner [$self runner]
        scope_guard runner [list $runner destroy]
        $runner run {*}$args
    }

    method runner args {
        RunContext $self.runner.%AUTO% {*}$args \
            -quiet $options(-quiet) \
            -dry-run $options(-dry-run) \
            -registry $myTaskSetRegistry -toplevel $self
    }
}

source $TclTaskRunner::libDir/builder.tcl
source $TclTaskRunner::libDir/context.tcl
source $TclTaskRunner::libDir/registry.tcl

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

    set def [$self use $taskFile]
    
    # XXX: 複雑すぎるよね. 自由度を損ねずに、簡単化するには？
    [$self runner -debug [$self cget -debug]] \
        run $def {*}$args
}

if {![info level] && [info script] eq $::argv0} {

    TclTaskRunner toplevel {*}$::argv

}
