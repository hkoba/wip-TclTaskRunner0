#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

snit::type ::TclTaskRunner::RunContext {
    variable myWorker ""
    variable myVisited -array []
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

    method run {scope {targetOrMethod ""} args} {
        if {[info commands $scope] eq "" && [regexp ^@ $scope]
            && $options(-registry) ne ""} {
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
            if {$options(-silent)} {
                $self dputs 0 running $scope target $targetOrMethod
            }
            set result [{*}$myWorker [$scope runtime lambda\
                                          {*}$targetOrMethod {*}$args]]
            if {!$options(-silent) && $result ne ""} {
                puts $options(-log-fh) $result
            }
            set result
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
            $self dputs $depth [$scope varName myDeps] \
                [set [$scope varName myDeps]]
        }

        array set predMtime []
        foreach pred $depends {
            $self dputs $depth testing $pred from $targetTuple
            if {[set v [default myVisited($pred) 0]] == 0} {
                $self update $pred [+ $depth 1]
            } elseif {$v == 1} {
                error "Task $pred and $targetTuple are circularly defined!"
            }
            set predMtime($pred) [$self mtime $pred $depth]
        }
        
        set thisMtime [$self mtime $targetTuple $depth]

        foreach pred $depends {
            if {$thisMtime < $predMtime($pred)} {
                lappend changed $pred
            } elseif {$predMtime($pred) == -Inf && $thisMtime != -Inf} {
                $self dputs $depth pred is not changed but infinitely old: $pred
                lappend changed $pred
            } else {
                $self dputs $depth Not changed $pred \
                    mtime $predMtime($pred) $targetTuple $thisMtime
            }
        }

        set myVisited($targetTuple) 2
        
        if {[llength $changed]
            || ($depends eq "" && $thisMtime == -Inf)} {
            $self target try action $targetTuple $depth
        } else {
            $self dputs $depth No need to update $target
        }
    }
    
    method {fake mtime} targetTuple {
        set vn myMtime($targetTuple)
        if {![info exists $vn]} {
            $self touch mtime $targetTuple
        }
    }

    method {touch mtime} targetTuple {
        set myMtime($targetTuple) \
            [expr {[clock microseconds]/1000000.0}]
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
            [$scope target subst $target $script]
    }

    method {worker apply-to} {scope target depth subst} {
        {*}$myWorker [$scope target lambda $target $subst]
    }

    proc is-ok-or {resList default} {
        expr {[llength $resList] ? [lindex $resList 0] : $default}
    }

    method relative-filename scope {
        $options(-registry) relative-filename [$scope cget -file]
    }

    method {target try check} {targetTuple depth} {
        lassign $targetTuple scope - target
        set scriptType check
        set script [dict-default [$scope target get $target] $scriptType]
        if {$script eq ""} {
            $self dputs $depth No $scriptType script for $targetTuple
            return
        }
        $self dputs $depth running $scriptType script\
            for $targetTuple = [string trim $script]

        set rc [catch {
            $self worker subst-apply-to $scope $target $depth $script
        } resList optDict]

        if {$rc == 1} {
            dict set optDict -errorcode [list TCLTASK_ERROR check \
                                            [dict get $optDict -errorcode]]
            return -code TCL_ERROR  \
                -options $optDict "\[[$self relative-filename $scope]:$target\] Runtime error from check script: $resList"
        }

        $self dputs $depth ==> $resList

        set myState($targetTuple,$scriptType) $resList
        
        if {$resList ne ""} {
            set rest [lassign $resList ok]
            if {$ok} {
                set mtime [$self touch mtime $targetTuple]

                $self dputs $depth target mtime is updated: \
                    $targetTuple mtime $mtime
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
        
        set subst [$scope target subst $target $script]

        set rc [catch {
            $self worker apply-to $scope $target $depth $subst
        } resList optDict]

        if {$rc == 1} {
            dict set optDict -errorcode [list TCLTASK_ERROR check \
                                            [dict get $optDict -errorcode]]
            return -code TCL_ERROR  \
                -options $optDict "\[[$self relative-filename $scope]:$target\] Runtime error from action script: $resList"
        }
            
        $self dputs $depth ==> $resList

        set myState($targetTuple,$scriptType) $resList
            
        set postCheckRes [$self target try check $targetTuple $depth]
        if {![is-ok-or $postCheckRes yes]} {
                
            if {$options(-dry-run)} {
                # postcheck usually fail when dry-run mode.

            } elseif {[set diag [string trim [$scope target diag $target]]]
                      ne ""} {
                $self target diag $target \
                    [$scope target subst $target $diag] \
                    $postCheckRes
                
            } else {
                error "postcheck failed after action $targetTuple\
                           - postCheck=$postCheckRes"
            }
        }

        if {$options(-dry-run)
            && [set mtime [$self fake mtime $targetTuple]] ne ""
        } {
            $self dputs $depth target mtime is updated for dry-run: \
                $targetTuple mtime $mtime
        }
    }
    
    method {target diag} {target diag result} {
        return -code error \
            -errorcode [list failed-target $target result $result] \
            $diag
    }
}
