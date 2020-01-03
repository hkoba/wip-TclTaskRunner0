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
    }
}

snit::type ::TclTaskRunner::TaskSetDefinition {
    option -parent
    option -name ""
    
    option -tasks
    onconfigure -tasks tasks {install myTasks using set tasks}
    variable myTasks [dict create]

    option -files
    onconfigure -files files {install myFiles using set files}
    variable myFiles [dict create]

    variable myKidsDict [dict create]
    
    typemethod create-in {parent name args} {
        if {[$parent taskset exists $name]} {
            error "Conflicting taskset name '$name'"
        }
        set ts [$type create $parent.$name {*}$args -parent $parent]
        $parent taskset add $ts
        set ts
    }

    method {target depends task} name {
        dict-default [dict get $myTasks $name] depends []
    }
    method {target depends file} name {
        dict-default [dict get $myFiles $name] depends []
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
    variable myRootTaskSet ""
    
    option -toplevel ""
    option -root
    onconfigure -root root {
        install myRootTaskSet using set root
    }

    ::TclTaskRunner::io_util

    constructor args {
        $self configurelist $args
        if {$myRootTaskSet eq ""} {
            install myRootTaskSet using TaskSetDefinition $self.root
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
        upvar 1 $varName dict
        # XXX
    }

    method {target add} {varName targetName args} {
        upvar 1 $varName dict
        $self verify target $targetName {*}$args
        set target [dict create public no {*}$args]
        set kind [if {[dict exists $target check]} {
            string cat task
        } else {
            string cat file
        }]
        # XXX: dependsFiles, dependsTasks を変形して depends へ
        dict set dict $kind $targetName $target
        set targetName
    }
    
    method {verify target} {name args} {}

    method add {kind varName targetName args} {
        upvar 1 $varName dict
        # XXX: conflict
        dict set dict $kind $targetName [list $kind $targetName {*}$args]
    }

    method {annotate public} {varName kind targetName args} {
        upvar 1 $varName dict
        if {$kind ne "target"} {error "Invalid kind: $kind"}
        $self target add $varName $targetName {*}$args \
            public yes
    }

    method {annotate default} {varName kind targetName args} {
        upvar 1 $varName dict
        if {$kind ne "target"} {error "Invalid kind: $kind"}
        $self target add $varName $targetName {*}$args
        dict set dict default $targetName
    }

    #========================================

    method {taskset define file} {fn args} {
        set parent [from args -parent $myRootTaskSet]
        set name [from args -name [file rootname [file tail $fn]]]

        set dict [$self taskset parse file $fn {*}$args]

        TaskSetDefinition create-in $parent $name \
            -tasks [dict-default $dict task] \
            -files [dict-default $dict file] 
    }

    method {taskset parse file} {fn args} {
        set script [$self read_file $fn]
        
        $self taskset parse script $script
    }
    
    method {taskset parse script} script {
        $self prepare-context dict
        
        $myInterp eval $script

        # XXX: ここで dict の中身のエラー検査

        set dict
    }
    
    method {taskset compile} {name dict} {

        # puts $dict

        # XXX: そもそも myInterp で eval するんじゃなかったんかい
        # で、myInterp の特定の変数に溜まった内容を使って
        # 実際のスクリプトを構築する、と。
        
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
