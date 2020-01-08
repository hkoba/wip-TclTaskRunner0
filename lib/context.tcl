#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

snit::type ::TclTaskRunner::RunContext {
    variable myWorker ""
    variable myVisited -array []
    variable myUpdated -array []
    variable myMtime   -array []
    variable myState   -array []
    
    option -registry
    option -toplevel

    option -dry-run no
    
    ::TclTaskRunner::use_logging

    option -worker
    onconfigure -worker worker {
        install myWorker using set worker
    }

    constructor args {
        $self configurelist $args
        $self worker init
    }

    method {worker init} {} {
        if {$myWorker eq ""} {
            install myWorker using list interp eval {}
        }
    }

    method run {scope {targetOrMethod ""} args} {
        if {[info commands $scope] eq "" && [regexp ^@ $scope] && $options(-registry) ne ""} {
            set scope [$options(-registry) get $scope]
        }
        if {$targetOrMethod eq ""} {
            if {[set targetOrMethod [$scope cget -default]] eq ""} {
                error "No default target in $scope"
            }
        }
        if {[set fileName [$scope cget -file]] ne ""} {
            pushd_scope prevDir [file dirname $fileName]
        }
        if {[$scope target exists $targetOrMethod]} {
            set target $targetOrMethod
            set kind [$scope target kind $target]
            $self update [list $scope $kind $target] 0 {*}$args
        } elseif {[$scope runtime can $targetOrMethod]} {
            $scope runtime invoke $targetOrMethod {*}$args
        } else {
            error "No such target/method in $scope: $targetOrMethod"
        }
    }

    # targetTuple == [list $scope $kind $name]

    method update {targetTuple depth args} {
        lassign $targetTuple scope kind target

        if {![$scope target exists $target]} {
            if {$depth == 0} {
                error "Unknown file or target: $target"
            }
            return 0
        }

        $self dputs $depth start updating [$scope cget -name] $target

        if {[set fileName [$scope cget -file]] ne ""} {
            pushd_scope prevDir [file dirname $fileName]
        }

        set changed []
        set myVisited($targetTuple) 1
        
        set depends [$scope target depends $target]
        $self dputs $depth scope $scope target $target deps $depends
        if {$options(-debug) >= 3} {
            $self dputs $depth [$scope varName myDeps] [set [$scope varName myDeps]]
        }

        foreach pred $depends {
            $self dputs $depth testing $pred from $targetTuple
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
                $self dputs $depth pred is not changed but infinitely old: $pred
                lappend changed $pred
            } else {
                $self dputs $depth Not changed $pred mtime $predMtime $targetTuple $thisMtime
            }
        }
        
        set myVisited($targetTuple) 2
        
        if {[llength $changed] || $depends eq ""} {
            $self target try action $targetTuple $depth
        } else {
            $self dputs $depth No need to update $target
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
    
    method {worker subst-apply-to} {scope target depth script} {
        $self worker apply-to $scope $target $depth \
            [$self target subst script $scope $target $script]
    }

    method {worker apply-to} {scope target depth subst} {
        set targetNS [$scope runtime typename]
        {*}$myWorker [list apply [list {self target} $subst $targetNS] \
                          [$scope runtime instance] $target]
    }

    method {target subst script} {scope target script} {
        set vmap [$scope var-map $target]
        string map $vmap $script
    }

    proc is-ok-or {resList default} {
        expr {[llength $resList] ? [lindex $resList 0] : $default}
    }

    method {target try check} {targetTuple depth} {
        lassign $targetTuple scope - target
        set scriptType check
        set script [dict-default [$scope target get $target] $scriptType]
        if {$script eq ""} {
            $self dputs $depth No $scriptType script for $targetTuple
            return
        }
        $self dputs $depth running $scriptType script for $targetTuple = [string trim $script]

        set resList [$self worker subst-apply-to $scope $target $depth $script]
        
        $self dputs $depth ==> $resList

        set myState($targetTuple,$scriptType) $resList
        
        if {$resList ne ""} {
            set rest [lassign $resList ok]
            if {$ok} {
                set myMtime($targetTuple) \
                    [set mtime [expr {[clock microseconds]/1000000.0}]]

                $self dputs $depth target mtime is updated: $targetTuple mtime $mtime
            }
        }
        
        set resList
    }
    
    method {target try action} {targetTuple depth} {
        lassign $targetTuple scope - target

        if {[is-ok-or [$self target try check $targetTuple $depth] no]} return

        set scriptType action
        set script [dict-default [$scope target get $target] $scriptType]
        if {$script eq ""} {
            $self dputs $depth No $scriptType script for $targetTuple
            return
        }
        
        set subst [$self target subst script $scope $target $script]

        if {$options(-quiet)} {
            $self dputs $depth running $scriptType script for $targetTuple = [string trim $subst]
        } else {
            puts $options(-log-fh) "$options(-log-prefix)[string trim $subst]"
        }

        if {!$options(-dry-run)} {
            set resList [$self worker apply-to $scope $target $depth $subst]
            
            $self dputs $depth ==> $resList

            set myState($targetTuple,$scriptType) $resList
            
            if {![is-ok-or [$self target try check $targetTuple $depth] yes]} {
                error "postcheck failed after action $targetTuple"
            }
        }
        
        lappend myUpdated($targetTuple)
    }
}
