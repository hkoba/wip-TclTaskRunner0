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
source $::TclTaskRunner::libDir/workermacro.tcl

snit::type TclTaskRunner {
    component myTaskSetRegistry -public registry

    variable myBuilder

    option -dry-run no
    ::TclTaskRunner::use_logging

    ::TclTaskRunner::use_worker

    option -report-command []

    option -dump no
    option -show-dependency no

    typevariable ourTaskSetType TaskSetDefinition

    constructor args {
        install myTaskSetRegistry using TaskSetRegistry $self.registry
        $self configurelist $args
        install myBuilder using TaskSetBuilder $self.builder \
            -toplevel $self -registry $myTaskSetRegistry \
            -task-set-type $ourTaskSetType \
            -debug $options(-debug)
        
        $self worker init
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
                $self verify-file {*}[lsort -dictionary \
                                          [glob -nocomplain \
                                               -directory $path *.tcltask]]

            } elseif {![file exists $path]
                      && [set expanded [glob -nocomplain $path]] ne ""
                  } {
                $self verify-file {*}[lsort -dictionary $expanded]
            } else {
                $self use $path
            }
        }
    }
    
    method verify-file args {
        foreach fn $args {
            $self use $fn
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
                    $type alert "failed-target $taskFn: $result"
                } else {
                    puts stderr "failed-target $taskFn\n$::errorInfo"
                }
                return NG
            }
        }
        return OK
    }

    method report {result {exitWith 1}} {
        if {$options(-report-command) ne ""} {
            $options(-report-command) $result
        } else {
            if {$result eq "OK"} {
                puts $result
            } else {
                $type alert $result
                if {$exitWith ne ""} {
                    exit $exitWith
                }
            }
        }
    }

    method runner args {
        $self worker sync

        RunContext $self.runner.%AUTO% {*}$args \
            -silent $options(-silent) \
            -dry-run $options(-dry-run) \
            -worker $myWorker \
            -debug $options(-debug) \
            -registry $myTaskSetRegistry -toplevel $self
    }
}

source $TclTaskRunner::libDir/builder.tcl
source $TclTaskRunner::libDir/context.tcl
source $TclTaskRunner::libDir/registry.tcl
source $TclTaskRunner::libDir/termcolor.tcl
source $TclTaskRunner::libDir/namespace-util.tcl

snit::method TclTaskRunner usage args {
    return "Usage: [file tail $TclTaskRunner::scriptFn] ?main.tcltask?"
}

snit::typemethod TclTaskRunner parse-opts {argsVar} {
    upvar 1 $argsVar argv
    parsePosixOpts argv alias [dict create n dry-run s silent d debug]
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

    set opts [list -debug [default ::env(DEBUG) 0]]
    lappend opts {*}[$type parse-opts args]

    if {[llength $args]} {
        set args [lassign $args taskFile]
    } else {
        set taskFile main.tcltask
    }

    $type $self {*}$opts {*}[$type parse-opts args]
        
    if {![file exists $taskFile]} {
        puts stderr [$self usage]
        exit 1
    }

    set def [$self use $taskFile]

    if {[$self cget -dump]} {
        puts [$def dump]
        return
    }

    if {[$self cget -show-dependency]} {
        set target [if {$args ne ""} {
            lindex $args 0
        } else {
            $def cget -default
        }]
        if {![$def target exists $target]} {
            error "No such target in $taskFile: $target"
        }
        puts "target $target depends: [$def target depends $target]"
        return
    }

    set runner [$self runner]
    scope_guard runner [list $runner destroy]

    set rc [catch {$runner run $def {*}$args} result optDict]
    switch $rc {
        0 - 2 {
            return $result
        }
        1 {
            if {[lindex [dict get $optDict -errorcode] 0] eq "TCLTASK_ERROR"} {
                puts stderr "ttr: *** $result"
            } else {
                puts stderr "ttr: !!! Unknown internal error in $taskFile: ($optDict): stacktrace: $::errorInfo"
            }
            exit 1
        }
        3 - 4 - default {
            return -code $rc $result
        }
    }
}

# snit::method TclTaskRunner handle-error {args} {
# }

if {![info level] && [info script] eq $::argv0} {

    TclTaskRunner toplevel {*}$::argv

}
