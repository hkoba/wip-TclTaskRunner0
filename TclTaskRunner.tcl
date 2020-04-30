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

    option -report-command []

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
    
    method verify args {
        foreach path $args {
            if {[file isdirectory $path]} {
                $self verify {*}[lsort -dictionary [glob -nocomplain -directory $path *.tcltask]]
                
            } elseif {![file exists $path]} {
                $self verify {*}[lsort -dictionary [glob -nocomplain $path]]
            } else {
                $self use $path
            }
        }
    }

    method run {scopeOrFileName args} {

        set scope [if {[file exists $scopeOrFileName]} {
            $self use $scopeOrFileName
        } elseif {[$myTaskSetRegistry exists $scopeOrFileName]} {
            set scopeOrFileName
        } else {
            error "No such taskset: $scopeOrFileName"
        }]

        set runner [$self runner]
        scope_guard runner [list $runner destroy]
        $runner run $scope {*}$args
    }

    method run-all args {
        foreach taskFn $args {
            if {[catch {$self run $taskFn} result resOpts]} {
                if {[lindex [set ec [dict-default $resOpts -errorcode]] 0]
                    eq "failed-target"} {
                    $type alert $result
                } else {
                    puts stderr $::errorInfo
                }
                return NG
            }
        }
        return OK
    }

    method report result {
        if {$options(-report-command) ne ""} {
            $options(-report-command) $result
        } else {
            if {$result eq "OK"} {
                puts $result
            } else {
                $type alert $result
            }
        }
    }

    method runner args {
        RunContext $self.runner.%AUTO% {*}$args \
            -quiet $options(-quiet) \
            -dry-run $options(-dry-run) \
            -debug $options(-debug) \
            -registry $myTaskSetRegistry -toplevel $self
    }
}

source $TclTaskRunner::libDir/builder.tcl
source $TclTaskRunner::libDir/context.tcl
source $TclTaskRunner::libDir/registry.tcl
source $TclTaskRunner::libDir/termcolor.tcl

snit::method TclTaskRunner usage args {
    return "Usage: [file tail $TclTaskRunner::scriptFn] ?main.tcltask?"
}

snit::typemethod TclTaskRunner oneshot {varName script args} {
    upvar 1 $varName self
    
    set oldDir [pwd]
    scope_guard oldDir [list cd $oldDir]

    set self [$type %AUTO% {*}$args]

    scope_guard self [list $self destroy]
    
    uplevel 1 $script
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

    set runner [$self runner]
    scope_guard runner [list $runner destroy]

    $runner run $def {*}$args
}

if {![info level] && [info script] eq $::argv0} {

    TclTaskRunner toplevel {*}$::argv

}
