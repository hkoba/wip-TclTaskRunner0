#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

# snit::type は comm に送信できるけど、instance の送信はまだ確立できてない
# なのでクラスを動的に生成する方向で。
# …全部 typemethod でも良かった可能性も？

package require snit
package require fileutil

namespace eval TclTaskRunner {
    if {![info exists libDir]} {
        apply {{libDir} {
            source $libDir/utils.tcl
            source $libDir/iomacro.tcl
            source $libDir/typemacro.tcl
            source $libDir/registry.tcl
            source $libDir/logmacro.tcl
            source $libDir/tasksetdef.tcl
        }} [file dirname [::fileutil::fullnormalize [info script]]]
    }
}

snit::type ::TclTaskRunner::TaskSetBuilder {
    variable myInterp
    variable myRegistry ""
    
    option -toplevel ""
    option -registry ""
    option -popd-after-load no

    variable myTaskSetType TaskSetDefinition
    option -task-set-type
    onconfigure -task-set-type typ {
        set myTaskSetType $typ
    }

    onconfigure -registry root {
        install myRegistry using set root
    }

    ::TclTaskRunner::io_util
    ::TclTaskRunner::use_logging

    constructor args {
        $self configurelist $args
        if {$myRegistry eq ""} {
            install myRegistry using TaskSetRegistry $self.registry
        }
        install myInterp using interp create $self.interp

        $myInterp eval {rename proc __proc}
        $myInterp eval {rename variable __variable}
        $myInterp eval {rename package __package}
    }
    
    #========================================

    variable myPkgDepth 0
    variable mySourceDepth 0
    variable myTargetDecls []

    method is-toplevel {} {expr {$myPkgDepth == 0 && $mySourceDepth == 0}}

    method expand-declaration {keyword} {
        interp alias $myInterp $keyword
    }
    method define-declaration {varName keyword as args} {
        interp alias $myInterp $keyword \
            {} $self {*}$args $varName
        set keyword
    }
    method define-declaration!! {args} {
        set keyword [$self define-declaration {*}$args]
        lappend myTargetDecls $keyword
        set keyword
    }

    method prepare-context varName {

        $self define-declaration $varName default => annotate default
        $self define-declaration $varName public  => annotate public

        $self define-declaration!! $varName target  => target add
        $self define-declaration!! $varName TARGET  => target add

        $self define-declaration!! $varName target-file => target add-kind file
        $self define-declaration!! $varName FILE        => target-file add

        $self define-declaration $varName variable    => variable add
        $self define-declaration $varName proc        => proc add

        $self define-declaration $varName option      => misc add option
        $self define-declaration $varName method      => misc add method

        $self define-declaration $varName use         => declare use
        $self define-declaration $varName import      => declare import
        $self define-declaration $varName package     => declare package
    }

    method {declare use} {varName name args} {
        upvar 1 $varName def
        set asName [from args as ""]
        if {![$myRegistry parse-use-spec $name rootName]} {
            error "Bad argument for \[use\] statement. \
            '$name' should be either @xxx or xxx.tcltask"
        }
        set extName @$rootName
        set subdef [$self taskset ensure-loaded \
                        [$self filename-from-extern $rootName $def] \
                        [+ 1 [$def cget -depth]]]
        $def extern add $extName $subdef \
            [if {$asName ne ""} {$myRegistry parse-use-spec $asName}]

        set extName
    }

    method {declare import} {varName what _from fromFn} {
        upvar 1 $varName def
        if {$_from ne "from"} {
            error "Only \[import pattern from file] is supported"
        }

        if {[set realScriptFn [$self lookup-source-from-file \
                                   [$def cget -file] $fromFn]] eq ""} {
            error "Can't find $fromFn from directory [$def directory]"
        }

        set gotNS [uplevel #0 [list source $realScriptFn]]
        if {$gotNS eq ""} {
            error "\[import $what from $fromFn\] didn't return namespace"
        }

        set mySourceDepth 1
        # Why not worked: XXX:  scope_guard here [list set mySourceDepth 0]

        # Eval it in the builder interpreter too (to capture [package require])
        $myInterp eval [list namespace eval :: [list uplevel #0 [list source $realScriptFn]]]

        set mySourceDepth 0

        $def import add $what $fromFn $gotNS
    }

    method lookup-source-from-file {fromFn lookupFn} {
        #
        # 1. Lookup $lookupFn from actual tcltask location.
        #
        if {[set fn [$self lookup-upward-from [file dirname $fromFn] $lookupFn]] ne ""} {
            return $fn
        }
        #
        # 2. When 1. failed and $fromFn is a symlink, lookup $lookupFn
        # from fully-symlink-resolved path of $fromFn.
        #
        if {[file type $fromFn] eq "link"
            &&
            [set fn [$self lookup-upward-from [file dirname [fileutil::fullnormalize $fromFn]] $lookupFn]] ne ""} {
            return $fn
        }
    }

    method lookup-upward-from {dir fn} {
        set nameList [file split $dir]
        for {set i [expr {[llength $nameList] - 1}]} {$i >= 0} {incr i -1} {
            set absFn [file join {*}[lrange $nameList 0 $i] $fn]
            if {[file exists $absFn]} {
                return $absFn
            }
        }
    }

    method {declare package} {defVar cmd args} {
        upvar 1 $defVar def
        # "import from → package require" should be traced.
        if {!$myPkgDepth && $cmd eq "require"} {
            $myRegistry package require {*}$args
        }
        incr myPkgDepth
        set rc [catch {
            $myInterp eval [list namespace eval :: [list __package $cmd {*}$args]]
        } result opts]
        incr myPkgDepth -1
        return -code $rc -options $opts $result
    }

    method filename-from-extern {rootName baseDef} {
        set baseDir [$baseDef dir]
        return $baseDir/$rootName.tcltask
    }

    method {target-file add} {varName targetName dependsFiles action args} {
        upvar 1 $varName def
        lassign [$self precheck target file $def $targetName \
                     dependsFiles $dependsFiles action $action \
                     {*}$args] \
            kind dict
        dict-set-default dict public no
        $def file add $targetName $dict
        set targetName
    }

    method {target add} {varName targetName args} {
        upvar 1 $varName $varName
        $self target add-kind task $varName $targetName {*}$args
    }

    method {target add-kind} {kind varName targetName args} {
        upvar 1 $varName def
        lassign [$self precheck target task $def $targetName {*}$args] \
            kind dict
        dict-set-default dict public no
        $def $kind add $targetName $dict

        interp alias $myInterp $targetName \
            {} $self target configure $varName $targetName

        set targetName
    }


    method {target configure} {varName targetName method kind args} {
        upvar 1 $varName def
        if {$method ne "depends"} {
            error "Not yet implemented: $method"
        }
        set value [if {$kind eq "target"} {
            $self target add $varName {*}$args
        } elseif {[llength $args] == 1} {
            lindex $args 0
        } else {
            error "Not yet implemented: $targetName $name $kind $args"
        }]

        $def target lappend $method $targetName $value
    }

    #
    # Keyword dictionary of target definition.
    #
    method {precheck target} {kind def targetName args} {
        set dict [dict create]
        set seen [dict create]
        foreach {name value} $args {

            if {[$myTaskSetType knownAliases $name alias]} {

                dict lappend seen $name $alias
                
            } elseif {[$myTaskSetType knownKey $name]} {
               
                dict lappend seen $name $name

            } else {
                error "Unknown item '$name' in target '$targetName' \
                             file '[$def cget -file]'"
            }

            if {[llength [set dup [dict get $seen $name]]] >= 2} {
                if {[lindex $dup 0] eq [lindex $dup 1]} {
                    error "Duplicate item '$name' in target '$targetName' \
                             file '[$def cget -file]'"
                } else {
                    error "Conflicting item [join $dup] in target '$targetName'\
                             file '[$def cget -file]'"
                }
            }

            if {[info exists alias]} {
                set name $alias
            }

            dict set dict $name $value
        }

        list $kind $dict
    }

    method {variable add} {defVar varName args} {
        upvar 1 $defVar def
        if {![$self is-toplevel]} {
            $myInterp eval [list __variable $varName {*}$args]
            return
        }
        if {![regexp {^\w+$} $varName]} {
            # Do not expose this name to $myInterp
        } elseif {$args eq ""} {
            $myInterp eval [list __variable $varName]
        } elseif {[llength $args] == 1} {
            $myInterp eval [list set $varName [lindex $args 0]]
        } elseif {[llength $args] == 2 && [lindex $args 0] eq "-array"} {
            $myInterp eval [list array set $varName [lindex $args 1]]
        } else {
            error "Invalid variable declaration: $varName $args"
        }
        $def misc add variable $varName [list variable $varName {*}$args]
    }

    method {proc add} {defVar procName args} {
        upvar 1 $defVar def
        $myInterp eval [list __proc $procName {*}$args]
        if {![$self is-toplevel]} return
        $def misc add proc $procName [list proc $procName {*}$args]
    }

    method {misc add} {kind varName targetName args} {
        upvar 1 $varName def
        # XXX: conflict
        $def misc add $kind $targetName [list $kind $targetName {*}$args]
    }

    method {annotate public} {varName kind targetName args} {
        if {$kind ni $myTargetDecls} {error "Invalid kind: $kind"}
        uplevel 1 [list {*}[$self expand-declaration $kind] $targetName {*}$args \
                       public yes]
    }

    method {annotate default} {varName kind targetName args} {
        if {$kind ni $myTargetDecls} {error "Invalid kind: $kind"}
        set cmd [list {*}[$self expand-declaration $kind] $targetName {*}$args \
                       public yes]
        uplevel 1 $cmd
        upvar 1 $varName def
        $def configure -default $targetName
    }

    #========================================

    method {taskset ensure-loaded} {fn {depth 0}} {
        set name [$myRegistry relative-name $fn]
        if {![$myRegistry exists $name]} {
            set rc [catch {
                $self taskset define file $fn -depth $depth
            } error]
            if {$rc} {
                set diag "Can't load tcltask $fn: $error"
                if {$options(-debug)} {
                    append diag "\n==Original backtrace==\n$::errorInfo"
                }
                error $diag
            }
        }
        $myRegistry get $name
    }

    method {taskset define file} {origFn args} {
        set opts [lassign [$self taskset prepare file $origFn {*}$args] def]

        $self taskset compile $def {*}$opts
        
        set def
    }

    method {taskset prepare file} {origFn args} {
        set depth [from args -depth 0]

        set fn [fileutil::lexnormalize [file normalize $origFn]]

        set name [$myRegistry relative-name $fn]
        if {[$myRegistry exists $name]} {
            error "Conflicting name?? $name"
        }
        
        $myRegistry add $name \
            [set def [$myTaskSetType $myRegistry.$name \
                          -name $name -file $fn \
                          -depth $depth \
                          {*}$args]]

        $self dputs $depth define $name -file $fn

        $self taskset populate $def -file $fn -depth $depth
        
        list $def -depth $depth
    }

    method {taskset populate} {def args} {
        set depth [from args -depth 0]

        if {$options(-popd-after-load)} {
            pushd_scope prevDir [$myRegistry cget -root-dir]
        } else {
            cd [$myRegistry cget -root-dir]
        }

        $self prepare-context def
        
        set script [if {[set fn [from args -file ""]] ne ""} {
            $self read_file $fn
        } else {
            from args -script ""
        }]

        $myInterp eval [list apply {{fn script} {
            set oldScript [info script]
            info script $fn
            eval $script
            info script $oldScript
        }} $fn $script]

        if {$options(-debug) >= 2} {
            $self dputs $depth [$def cget -name] => [$def dump]
        }

        set rc [catch {$self taskset finalize $def {*}$args} error]
        if {$rc} {
            if {$options(-debug)} {
                error "Error found in [$def cget -name]: $error\n\
                Dump: [$def dump]\n"
            } else {
                error $error
            }
        }

        if {$options(-debug) >= 3} {
            $self dputs $depth ==> [$def dump]
        }

        set def
    }
    
    method {taskset finalize} {def args} {
        set depth [from args -depth 0]

        upvar 0 [$def varName myDeps] taskDict
        # if {[$def cget -default] eq ""} {
        #     set firstTarget [lindex [dict keys $taskDict] 0]
        #     puts "firstTarget $firstTarget"
        #     $def configure -default $firstTarget
        # }
        foreach name [dict keys $taskDict] {
            dict update taskDict $name task {
                if {[dict exists $task depends]} {
                    dict lappend task dependsTasks \
                        {*}[dict get $task depends]
                    dict unset task depends
                }
            }
        }
        dict for {name task} $taskDict {
            set deps []
            foreach depTask [dict-default $task dependsTasks] {
                lappend deps [if {[$myRegistry parse-extern $depTask \
                                       extScopeName extTarget]} {
                    if {[$def extern exists $extScopeName]} {
                        # XXX: Refactor!
                        set extScope [$def extern get $extScopeName]
                        $extScope target spec $extTarget
                    } else {
                        if {$options(-debug) >= 3} {
                            $self dputs $depth depTask $depTask is foreign \
                                for $def
                        }
                        $myRegistry resolve-spec $depTask [$def cget -name]
                    }
                } else {
                    $def target spec $depTask
                }]
            }
            foreach depFile [dict-default $task dependsFiles] {
                if {[$def target exists $depFile]} {
                    lappend deps [$def target spec $depFile]
                } else {
                    lappend deps [list $def file $depFile]
                }
            }
            dict set task depends $deps
            dict set taskDict $name $task
        }
    }

    method {taskset genscript} {def args} {
        set depth [from args -depth 0]

        set script [$def genscript]

        if {$options(-debug) >= 2} {
            $self dputs $depth =======
            $self dputs $depth runtime type:
            $self dputs $depth [string trim $script]
            $self dputs $depth =======
        }
        
        set script
    }

    method {taskset compile} {def args} {

        set script [$self taskset genscript $def {*}$args]

        uplevel #0 $script
    }
}

if {![info level] && [info script] eq $::argv0} {
    apply {{self} {
        if {[llength $::argv]} {
            lassign [$self taskset prepare file {*}$::argv] def
            puts [$self taskset genscript $def]
        }
    }} [::TclTaskRunner::TaskSetBuilder bld -debug 1]
}
