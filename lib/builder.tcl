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
    }
    
    #========================================

    method prepare-context varName {
        interp alias $myInterp default \
            {} $self annotate default $varName
        interp alias $myInterp public \
            {} $self annotate public $varName

        interp alias $myInterp target \
            {} $self target add $varName
        interp alias $myInterp TARGET \
            {} $self target add $varName
        
        interp alias $myInterp target-file \
            {} $self target-file add $varName
        interp alias $myInterp FILE \
            {} $self target-file add $varName
        
        interp alias $myInterp method \
            {} $self misc add method $varName
        interp alias $myInterp proc \
            {} $self misc add proc $varName

        interp alias $myInterp use \
            {} $self declare use $varName
        
        interp alias $myInterp import \
            {} $self declare import $varName
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
    }

    method {declare import} {varName what _from fromFn} {
        upvar 1 $varName def
        if {$_from ne "from"} {
            error "Only \[import pattern from file] is supported"
        }
        $def import add $what $fromFn
    }

    method filename-from-extern {rootName baseDef} {
        set baseDir [$baseDef dir]
        return $baseDir/$rootName.tcltask
    }

    method {target-file add} {varName targetName dependsFiles action} {
        upvar 1 $varName def
        set dict [dict create \
                      public no \
                      dependsFiles $dependsFiles action $action]
        $def file add $targetName $dict
        set targetName
    }

    method {target add} {varName targetName args} {
        upvar 1 $varName def
        lassign [$self precheck target $def $targetName {*}$args] \
            kind dict
        dict-set-default dict public no
        $def $kind add $targetName $dict
        set targetName
    }
    
    #
    # Keyword dictionary of target definition.
    #
    method {precheck target} {def targetName args} {
        set dict [dict create]
        foreach {name value} $args {
            if {![$myTaskSetType knownKey $name]} {
                error "Unknown item '$name' in target '$targetName' \
                file '[$def cget -file]'"
            }
            if {[dict exists $dict $name]} {
                error "Duplicate item '$name' in target '$targetName' \
                file '[$def cget -file]'"
            }
            dict set dict $name $value
        }
        set kind [if {[dict exists $dict check]} {
            value task
        } else {
            value file
        }]
        
        list $kind $dict
    }

    method {misc add} {kind varName targetName args} {
        upvar 1 $varName def
        # XXX: conflict
        $def misc add $kind $targetName [list $kind $targetName {*}$args]
    }

    method {annotate public} {varName kind targetName args} {
        if {$kind ne "target"} {error "Invalid kind: $kind"}
        uplevel 1 [list $self target add $varName $targetName {*}$args \
                       public yes]
    }

    method {annotate default} {varName kind targetName args} {
        if {$kind ne "target"} {error "Invalid kind: $kind"}
        uplevel 1 [list $self target add $varName $targetName {*}$args \
                       public yes]
        upvar 1 $varName def
        $def configure -default $targetName
    }

    #========================================

    method {taskset ensure-loaded} {fn {depth 0}} {
        set name [$myRegistry relative-name $fn]
        if {[$myRegistry exists $name]} {
            $myRegistry get $name
        } else {
            $self taskset define file $fn -depth $depth
        }
    }

    method {taskset define file} {origFn args} {
        set depth [from args -depth 0]

        set fn [fileutil::lexnormalize [file normalize $origFn]]

        set name [$myRegistry relative-name $fn]
        if {[$myRegistry exists $name]} {
            error "Conflicting name?? $name"
        }
        
        if {$options(-popd-after-load)} {
            pushd_scope prevDir [$myRegistry cget -root-dir]
        } else {
            cd [$myRegistry cget -root-dir]
        }

        $self dputs $depth define $name -file $fn

        $myRegistry add $name \
            [set def [$myTaskSetType $myRegistry.$name \
                          -name $name -file $fn \
                          -depth $depth \
                          {*}$args]]

        $self taskset populate $def -file $fn -depth $depth
        
        $self taskset compile $def -depth $depth
        
        set def
    }

    method {taskset populate} {def args} {
        set depth [from args -depth 0]

        $self prepare-context def
        
        $myInterp eval [if {[set fn [from args -file ""]] ne ""} {
            $self read_file $fn
        } else {
            from args -script ""
        }]

        if {$options(-debug) >= 2} {
            $self dputs $depth [$def cget -name] => [$def dump]
        }

        $self taskset finalize $def {*}$args

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

        set script [__EXPAND $ourTypeTemplate \
                        %TYPENAME% [$def runtime typename] \
                        %METHODS% [join [$def misc get method] \n] \
                        %PROCS% [join [$def misc get proc] \n] \
                        %DEPS% [$def deps] \
                       ]
        
        foreach spec [$def import list] {
            lassign $spec pattern fromFile
            set gotNS [uplevel #0 [list source $fromFile]]
            if {$gotNS ne ""} {
                append script [list namespace eval [$def runtime typename] \
                    [list apply {{ns args} {
                        foreach pat $args {
                            namespace import ${ns}::$pat
                        }
                    }} $gotNS {*}$pattern]]\n
            }
        }
        
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

        # type を即座に instantiate
        [$def runtime typename] create [$def runtime instance]
    }
    
    proc __EXPAND {template args} {
        string map $args $template
    }

    typevariable ourTypeTemplate {
        snit::type %TYPENAME% {
            option -props
            %METHODS%
            %PROCS%
            typevariable ourDeps {%DEPS%}
            method selfns {} {return $selfns}
            method {target list} {} {dict keys $ourDeps}
        }
    }
}

if {![info level] && [info script] eq $::argv0} {
    ::TclTaskRunner::TaskSetBuilder bld -debug 10
    puts [bld {*}$::argv]
}
