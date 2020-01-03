#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-


snit::type ::TclTaskRunner::RunContext {
    variable myWorker
    variable myVisited
    variable myUpdated
    variable myMtime
    
    variable myLogger

    option -registry
    option -toplevel

    proc + {x y} {expr {$x + $y}}

    method run {targetTuple args} {
        $self update $targetTuple 0 {*}$args
    }

    # scopeList は引数にしたほうが良いのでは
    # targetTuple == [list $scope $kind $name]

    method update {targetTuple depth args} {
        set changed []
        set myVisited($targetTuple) 1
        
        lassign $targetTuple scope kind target

        set depends [$scope target depends $target]
        foreach pred $depends {
            if {[set v [default myVisited($pred) 0]] == 0} {
                $self update $pred [+ $depth 1]
            } elseif {$v == 1} {
                error "Task $pred and $targetTuple are circularly defined!"
            }
            set thisMtime [$self mtime $targetTuple $depth]
            set predMtime [$self mtime $pred $depth]
            if {$thisMtime < $predMtime} {
                lappend changed $pred
            } elseif {$predMtime == -Inf && $thisMtime != -Inf} {
                # $self dputs $depth Not changed but infinitely old: $pred
                lappend changed $pred
            } else {
                # $self dputs $depth Not changed $pred mtime $predMtime $targetTuple $thisMtime
            }
        }
        
        set myVisited($targetTuple) 2
        
        if {[llength $changed] || $depends eq ""} {
            $self target try action $targetTuple $depth
        }
    }
    
    method mtime {targetTuple depth} {
        set vn myMtime($targetTuple)
        if {[info exists $vn]} {
            return [set $vn]
        }

        lassign $targetTuple scope kind target

        if {$kind eq "file"} {
            if {[$self file exists $target]} {
                $self file mtime $target
            } elseif {[$scope file exists $target]} {
                return -Inf
            } else {
                error "Unknown node or file: $target"
            }
        } else {
            $self target try check $targetTuple $depth
            default $vn -Inf
        }
    }
    
    method file {cmd args} {
        {*}$myWorker [list file $cmd {*}$args]
    }
    
    method {worker apply-to} {target script} {
        {*}$myWorker [list apply [list {self target} $script $selfns] \
                          $self $target]
    }

    method {target try} {kind targetTuple depth} {
        lassign $targetTuple scope kind target
        set script [dict-default [$scope target get $target] $kind]
        if {$script ne ""} {
            $self worker apply-to $target \
                [$scope script subst $target $script]
        }
    }
}
