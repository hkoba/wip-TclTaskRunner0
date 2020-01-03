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
    }
}

snit::type ::TclTaskRunner::TaskSetDefinition {
    option -parent
    option -name ""
    option -file ""
    option -default ""
    
    variable myExtern [dict create]

    variable myTasks [dict create]
    variable myFiles [dict create]

    typemethod create-in {parent name args} {
        if {[$parent taskset exists $name]} {
            error "Conflicting taskset name '$name'"
        }
        set ts [$type create $parent.$name {*}$args -name $name -parent $parent]
        $parent taskset add $ts
        set ts
    }

    method {target depends task} name {
        dict-default [dict get $myTasks $name] depends []
    }
    method {target depends file} name {
        dict-default [dict get $myFiles $name] depends []
    }

    method {extern add} {name dict} {
        dict set myExtern $name $dict
    }
    method all-tasks {} {set myTasks}
    method {task add} {name dict} {
        dict set myTasks $name $dict
    }
    method {file add} {name dict} {
        dict set myFiles $name $dict
    }
    method {file exists} name {
        dict exists $myFiles $name
    }

    method {taskset exists} name {
        dict exists $myKidsDict $name
    }
    method {taskset get} args {
        if {$args eq ""} {
            set myKidsDict
        } else {
            dict get $myKidsDict {*}$args
        }
    }
    method {taskset add} ts {
        set name [$ts cget -name]
        if {[dict exists $myKidsDict $name]} {
            error "Conflicting sub-taskset name '$name'"
        }
        dict set myKidsDict $name $ts
    }
}

snit::type ::TclTaskRunner::TaskSetBuilder {
    variable myInterp
    variable myRegistry ""
    
    option -toplevel ""
    option -registry ""
    onconfigure -root root {
        install myRegistry using set root
    }

    ::TclTaskRunner::io_util

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
        set subdef [$self taskset define file \
                        [$self filename-from-extern $name $def] \
                        -parent $def]
        $def extern add $name $subdef
    }

    method filename-from-extern {name baseDef} {
        if {![regsub ^@ $name {} rootName]} {
            error "Used name must start with @"
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
        $def $kind add $targetName [list $kind $targetName {*}$args]
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

    method {taskset define file} {fn args} {
        set name [$myRegistry intern $fn]

        puts "# def $name -file $fn"
        set def [TaskSetDefinition create-in $parent $name -file $fn]
        puts "# => name [$def cget -name]"

        $self taskset populate $def -file $fn
    }

    method {taskset populate} {def args} {
        $self prepare-context def
        
        $myInterp eval [if {[set fn [from args -file ""]] ne ""} {
            $self read_file $fn
        } else {
            from args -script ""
        }]

        $self taskset finalize $def

        set def
    }
    
    method {taskset finalize} def {
        set taskDict [$def all-tasks]
        foreach task [dict values $taskDict] {
            set deps []
            if {[dict-cut task dependsTasks]} {
                
            }
            if {[dict-cut task dependsFiles]} {
                
            }
            dict set task depends $deps
        }
    }

    method {verify dependsTasks} {def dependsList} {
        foreach dep $dependsList {
            if {[regexp ^@ $dep]} {
                
            }
        }
    }

    method {taskset compile} {name dict} {
        # TODO

	set def [__EXPAND $ourTypeTemplate \
		     %TYPENAME% $typeName \
                     %NAME% $name \
                     %PARENT% $parent \
                     %TASKS% [dict-default $dict task] \
                     %FILES% [dict-default $dict file] \
                     %METHODS% [join [dict values [dict-default $dict method]] \n] \
                     %PROCS% [join [dict values [dict-default $dict proc]] \n] \
                    ]
        
        # puts $def
        # return

        # %NAME%, %DEPS%, %PARENT%
        # option でも良かったのでは…←でも、変えたくなるから…

        uplevel #0 $def
        # expand 結果だけを見せたい時も有るはず

        # 親子関係を type に持たせるか、instance に持たせるか
        # → parent は typevariable, kids は instance variable でどうか。
        if {$parent ne ""} {
            $parent taskset add $typeName
        }

        # type を即座に instantiate
        $typeName $self.inst$myTaskSetCnt
    }
    
    proc __EXPAND {template args} {
	string map $args $template
    }

    typevariable ourTypeTemplate {
        snit::type %TYPENAME% {
	    option -props

            %METHODS%

            %PROCS%

            typevariable ourName [list %NAME%]
            method name {} {set ourName}

            typevariable ourParent [list %PARENT%]
            method parent {} {set ourParent}
            
            typevariable ourTasks [list %TASKS%]
            typevariable ourFiles [list %FILES%]
            method {target depends task} name {
                dict-default [dict get $ourTasks $name] depends []
            }
            method {target depends file} name {
                dict-default [dict get $ourFiles $name] depends []
            }

            method {file exists} name {
                dict exists $ourFiles $name
            }

            variable myKidsDict [dict create]
            method {taskset get} args {
                if {$args eq ""} {
                    set myKidsDict
                } else {
                    dict get $myKidsDict {*}$args
                }
            }
            method {taskset add} ts {
                set name [$ts name]
                if {[dict exists $myKidsDict $name]} {
                    error "Conflicting sub-taskset name $name"
                }
                dict set myKidsDict $name $ts
            }
        }
    }
}

if {![info level] && [info script] eq $::argv0} {
    ::TclTaskRunner::TaskSetBuilder bld
    puts [bld {*}$::argv]
}
