#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

snit::type ::TclTaskRunner::RunContext {
    variable myWorker ""
    variable myVisited -array []
    variable myMtime   -array []
    variable myState   -array []
    variable myErrored -array []
    variable myReport  []

    option -registry
    option -toplevel

    option -dry-run no
    option -check-only no
    
    ::TclTaskRunner::use_logging

    option -worker
    onconfigure -worker worker {
        install myWorker using set worker
    }

    method run {scope {targetOrMethod ""} args} {
        $self dputs 0 entering $scope target $targetOrMethod {*}$args
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
            $self dputs $depth predMtime $pred => $predMtime($pred)
        }
        
        set thisMtime [$self mtime $targetTuple $depth]
        $self dputs $depth dependency-check-for $targetTuple thisMtime $thisMtime

        foreach pred $depends {
            if {$thisMtime < $predMtime($pred)} {
                $self dputs $depth pred-changed: $pred predMtime $predMtime($pred)
                lappend changed $pred
            } elseif {$predMtime($pred) == -Inf && $thisMtime != -Inf} {
                $self dputs $depth pred is not changed but infinitely old: $pred
                lappend changed $pred
            } else {
                $self dputs $depth Not-changed $pred \
                    predMtime $predMtime($pred)
            }
        }

        set myVisited($targetTuple) 2

        set erroredPreds []
        foreach pred $depends {
            if {[info exists myErrored($pred)]} {
                lappend erroredPreds $pred
            }
        }

        if {[info exists myErrored($targetTuple)]} {
            $self dputs $depth error-detected-for $targetTuple \
                $myErrored($targetTuple)
            $self report add $targetTuple error $myErrored($targetTuple)
        } elseif {[llength $erroredPreds]} {
            $self dputs $depth blocked-by $erroredPreds
            $self report add $targetTuple blocked [list blocked-by $erroredPreds]
        } elseif {[llength $changed]} {
            $self dputs $depth because-of changed $changed
            if {$options(-check-only)} {
                $self report add $targetTuple needs-action [list changed $changed]
            } else {
                $self target try action $targetTuple $depth
            }
        } elseif {($depends eq "" && $thisMtime == -Inf)} {
            $self dputs $depth because-of thisMtime $thisMtime
            if {$options(-check-only)} {
                $self report add $targetTuple needs-action []
            } else {
                $self target try action $targetTuple $depth
            }
        } elseif {$options(-check-only) && $thisMtime == -Inf} {
            # In a real run, updating the (currently -Inf) preds would make
            # them newer than this target, so its action would run too.
            $self dputs $depth check-only: unsatisfied though deps unchanged
            $self report add $targetTuple needs-action []
        } else {
            $self dputs $depth No need to update $target
            $self report add $targetTuple ok []
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
            } elseif {$options(-check-only)} {
                if {![info exists myErrored($targetTuple)]} {
                    set myErrored($targetTuple) [list missing-file $target]
                    $self report add $targetTuple error $myErrored($targetTuple)
                }
                return -Inf
            } else {
                error "Dependency target file not found: $target"
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
        lassign $targetTuple scope kind target
        set scriptType check
        set script [dict-default [$scope target get $target] $scriptType]
        if {$script eq ""} {
            set frame [info frame -1]
            $self dputs $depth No check script for $kind $targetTuple \
                caller [list [dict get $frame proc] line [dict get $frame line]]
            return
        }
        $self dputs $depth running $scriptType script\
            for $targetTuple = [string trim $script]

        set rc [catch {
            $self worker subst-apply-to $scope $target $depth $script
        } resList optDict]

        if {$rc == 1} {
            if {$options(-check-only)} {
                set myErrored($targetTuple) [list check-error $resList]
                $self dputs $depth check-only: check script error \
                    for $targetTuple: $resList
                return
            }
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
        lassign $targetTuple scope kind target

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

        if {$kind eq "task" && [dict-default [$scope target get $target] check] eq ""} {
            $self dputs $depth touch $targetTuple
            $self touch mtime $targetTuple
        } else {
            $self dputs $depth No need to fake mtime
        }

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
    
    method {report add} {targetTuple status detail} {
        set vn myState($targetTuple,check)
        lappend myReport [dict create tuple $targetTuple \
                              status $status detail $detail \
                              check [default $vn ""]]
    }

    method {report list} {} {set myReport}

    # Renders the report collected during a -check-only traversal.
    # Returns a status: 0 (all satisfied), 1 (drift found), 2 (error found)
    method {report render} {{fh stdout}} {
        set counts [dict create ok 0 needs-action 0 error 0 blocked 0 \
                        aggregate 0]
        foreach row $myReport {
            lassign [dict get $row tuple] scope kind target
            set status [dict get $row status]
            set diag [lassign [dict get $row check] isOk]
            set label "[$scope cget -name]#$target"
            if {$status ne "error" && $kind eq "task"
                && [dict-default [set targetDict [$scope target get $target]] \
                        check] eq ""
                && [dict-default $targetDict action] eq ""} {
                # A pure aggregate target; its state is just that of its deps.
                dict incr counts aggregate
                continue
            }
            switch $status {
                ok {
                    puts $fh [string trimright "✔ $label $diag"]
                }
                needs-action {
                    set becauseOf []
                    foreach t [dict-default [dict get $row detail] changed] {
                        lappend becauseOf [lindex $t 2]
                    }
                    set line [string trimright "✘ $label $diag"]
                    if {$becauseOf ne ""} {
                        append line " (depends changed: $becauseOf)"
                    }
                    puts $fh $line
                }
                error {
                    puts $fh [string trimright "!! $label [dict get $row detail]"]
                }
                blocked {
                    set names []
                    foreach t [dict-default [dict get $row detail] blocked-by] {
                        lappend names [lindex $t 2]
                    }
                    puts $fh "⊘ $label (blocked by: $names)"
                }
            }
            dict incr counts $status
        }
        set summary "# [dict get $counts ok] ok,\
                 [dict get $counts needs-action] needs-action,\
                 [dict get $counts error] error"
        if {[dict get $counts blocked]} {
            append summary ", [dict get $counts blocked] blocked"
        }
        puts $fh $summary
        if {[dict get $counts error]} {
            return 2
        } elseif {[dict get $counts needs-action]} {
            return 1
        } else {
            return 0
        }
    }

    method {target diag} {target diag result} {
        return -code error \
            -errorcode [list failed-target $target result $result] \
            $diag
    }
}
