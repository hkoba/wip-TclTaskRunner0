#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

# snit::type は comm に送信できるけど、instance の送信はまだ確立できてない
# なのでクラスを動的に生成する方向で。
# …全部 typemethod でも良かった可能性も？

package require snit
package require fileutil

namespace eval TclTaskRunner {
    if {![info exists libDir]} {
        source [file dirname [::fileutil::fullnormalize [info script]]]/utils.tcl
        source [file dirname [::fileutil::fullnormalize [info script]]]/iomacro.tcl
        source [file dirname [::fileutil::fullnormalize [info script]]]/typemacro.tcl
        source [file dirname [::fileutil::fullnormalize [info script]]]/registry.tcl
        source [file dirname [::fileutil::fullnormalize [info script]]]/logmacro.tcl
    }
}

snit::type ::TclTaskRunner::TaskSetDefinition {
    option -parent
    option -name ""
    option -file ""
    option -default ""
    option -depth 0
    
    variable myExtern [dict create]

    variable myDeps [dict create]
    method varName varName {myvar $varName}

    # constructor args {
    #     puts "Constructor for $self is called"
    #     $self configurelist $args
    #     trace add variable [myvar myDeps] write [list apply {{self args} {
    #         puts "myDeps for $self is updated. $args"
    #     }} $self]
    #     trace add variable [myvar myDeps] unset [list apply {{self args} {
    #         puts "myDeps for $self is UNSET $args"
    #     }} $self]
    # }

    variable myMethods [dict create]
    variable myProcs [dict create]

    method {runtime typename} {} { return ${selfns}::runtime }
    method {runtime instance} {} { return ${selfns}::instance }
    method {runtime selfns} {} { return ${selfns} }

    method dump {} {
        list deps $myDeps methods $myMethods procs $myProcs extern $myExtern
    }

    method deps {} {set myDeps}
    method {target spec} name {
        set dict [dict get $myDeps $name]
        list $self [dict get $dict kind] $name
    }
    method {target exists} name {dict exists $myDeps $name}
    method {target get} name {dict get $myDeps $name}
    method {target kind} name {
        dict get $myDeps $name kind
    }
    method {target depends} name {
        dict-default [dict get $myDeps $name] depends []
    }

    method {extern add} {name dict} {
        dict set myExtern $name $dict
    }
    method {task add} {name dict} {
        dict set myDeps $name [dict merge $dict [dict create kind task]]
    }
    method {file add} {name dict} {
        dict set myDeps $name [dict merge $dict [dict create kind file]]
    }
    method {file exists} name {
        expr {[dict exists $myDeps $name]
              && 
              [dict get $myDeps $name kind] eq "file"}
    }

    variable myMisc [dict create method [] proc []]
    method {misc add} {kind name body} {
        dict set myMisc $kind $name $body
    }
    method {misc get} {kind {default ""}} {
        dict values [dict-default $myMisc $kind $default]
    }

    method var-map target {
        set depList []
        foreach d [$self target depends $target] {
            lassign $d scope kind dep
            lappend depList [if {$kind eq "file"} {
                set dep
            } else {
                set d
            }]
        }
        list \
            \$@ $target \
            \$< [string trim [lindex $depList 0]] \
            \$^ [lrange $depList 0 end]
    }
}

snit::type ::TclTaskRunner::TaskSetBuilder {
    variable myInterp
    variable myRegistry ""
    
    option -toplevel ""
    option -registry ""
    option -popd-after-load no

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

        interp alias $myInterp method \
            {} $self add method $varName
        interp alias $myInterp proc \
            {} $self add proc $varName

        interp alias $myInterp use \
            {} $self declare use $varName
    }

    method {declare use} {varName name args} {
        upvar 1 $varName def
        set asName [from args as ""]
        set subdef [$self taskset ensure-loaded \
                        [$self filename-from-extern $name $def] \
                        [+ 1 [$def cget -depth]]]
        $def extern add $name $subdef $asName
    }

    method filename-from-extern {name baseDef} {
        set pattern {^@|\.tcltask$}
        if {![regsub $pattern $name {} rootName]} {
            error "Bad argument for \[use\] statement. '$name' should match with $pattern"
        }
        set baseDir [file dirname [$baseDef cget -file]]
        return $baseDir/$rootName.tcltask
    }

    method {target add} {varName targetName args} {
        upvar 1 $varName def
        lassign [$self precheck target $def $targetName {*}$args] \
            kind dict
        dict-set-default dict public no
        $def $kind add $targetName $dict
    }
    
    typevariable ourKnownKeys [::TclTaskRunner::enum_dict \
                                   public check action \
                                   dependsTasks dependsFiles]

    method {precheck target} {def targetName args} {
        set dict [dict create]
        if {[llength $args] == 2} {
            lassign $args files action
            set args [list dependsFiles $files action $action]
        }
        foreach {name value} $args {
            if {![dict exists $ourKnownKeys $name]} {
                error "Unknown item $name in target $targetName file [$def cget -file]"
            }
            if {[dict exists $dict $name]} {
                error "Duplicate item $name in target $targetName file [$def cget -file]"
            }
            dict set dict $name $value
        }
        set kind [if {[dict exists $dict check]} {
            string cat task
        } else {
            string cat file
        }]
        
        list $kind $dict
    }

    method add {kind varName targetName args} {
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

    method {taskset ensure-loaded} {fn depth} {
        set name [$myRegistry relative-name $fn]
        if {[$myRegistry exists $name]} {
            $myRegistry get $name
        } else {
            $self taskset define file $fn -depth $depth
        }
    }

    method {taskset define file} {origFn args} {
        set depth [from args -depth 0]

        set fn [fileutil::fullnormalize $origFn]

        set name [$myRegistry relative-name $fn]
        if {[$myRegistry exists $name]} {
            error "Conflicting name?? $name"
        }
        
        if {$options(-popd-after-load)} {
            pushd_scope prevDir [$myRegistry cget -root-dir]
        } else {
            cd [$myRegistry cget -root-dir]
        }

        $self dputs $depth define @$name -file $fn

        $myRegistry add $name \
            [set def [TaskSetDefinition $myRegistry.$name \
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
    
    method {taskset finalize} def {
        upvar 0 [$def varName myDeps] taskDict
        # if {[$def cget -default] eq ""} {
        #     set firstTarget [lindex [dict keys $taskDict] 0]
        #     puts "firstTarget $firstTarget"
        #     $def configure -default $firstTarget
        # }
        dict for {name task} $taskDict {
            set deps []
            if {[dict-cut task dependsTasks]} {
                foreach depTask $dependsTasks {
                    lappend deps [if {[regexp ^@ $depTask]} {
                        $myRegistry resolve-spec $depTask [$def cget -name]
                    } else {
                        $def target spec $depTask
                    }]
                }
            }
            if {[dict-cut task dependsFiles]} {
                foreach depFile $dependsFiles {
                    if {[$def target exists $depFile]} {
                        lappend deps [$def target spec $depFile]
                    } else {
                        lappend deps [list $def file $depFile]
                    }
                }
            }
            dict set task depends $deps
            dict set taskDict $name $task
        }
    }

    method {taskset compile} {def args} {
        set depth [from args -depth 0]

        set script [__EXPAND $ourTypeTemplate \
                        %TYPENAME% [$def runtime typename] \
                        %METHODS% [join [$def misc get method] \n] \
                        %PROCS% [join [$def misc get proc] \n] \
                        %DEPS% [$def deps] \
                       ]
        
        if {$options(-debug) >= 2} {
            $self dputs $depth runtime type: $script
        }

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
