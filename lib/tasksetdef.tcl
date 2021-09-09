#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

package require snit
package require fileutil
package require struct::list

# This type implements $def in TclTaskRunner.tcl
# and also is called as $scope in RunContext.
snit::type ::TclTaskRunner::TaskSetDefinition {
    option -parent
    option -name ""
    option -file ""
    option -default ""
    option -depth 0
    
    typevariable ourKnownKeys [set knownKeys [::TclTaskRunner::enum_dict \
                                                  kind  public check action \
                                                  values \
                                                  diag \
                                                  dependsTasks dependsFiles]]
    typemethod knownKey name {
        dict exists $ourKnownKeys $name
    }

    typevariable ourKnownAliases [dict create let values]
    typemethod knownAliases {name {realNameVar ""}} {
        if {$realNameVar ne ""} {
            upvar 1 $realNameVar realVar
        }
        if {![dict exists $ourKnownAliases $name]} {
            if {$realNameVar ne "" && [info exists realVar]} {
                unset realVar
            }
            return 0
        }
        if {$realNameVar ne ""} {
            set realVar [dict get $ourKnownAliases $name]
        }
        return 1
    }

    variable myExtern [dict create]

    variable myDeps [dict create]
    method varName varName {myvar $varName}

    variable myMethods [dict create]
    variable myProcs [dict create]

    method dir {} {$self directory}
    method directory {} { file dirname $options(-file) }

    typemethod {instance namespaces} {} {
        return [namespace children $type Snit_inst*]
    }

    method {runtime typename} {} { return ${selfns}::runtime }
    method {runtime instance} {} { return ${selfns}::instance }
    method {runtime selfns} {} { return ${selfns} }
    method {runtime can} methodName {
        llength [${selfns}::instance info methods $methodName]
    }
    method {runtime invoke} args {
        ${selfns}::instance {*}$args
    }
    method {runtime lambda} args {
        set targetNS [$self runtime typename]
        list apply [list {self args} {$self {*}$args} $targetNS] \
            [$self runtime instance] {*}$args
    }

    method dump {} {
        list deps $myDeps methods $myMethods procs $myProcs extern $myExtern
    }

    method deps {} {set myDeps}
    method {target spec} name {
        if {$name eq ""} {
            set name $options(-default)
        }
        if {![dict exists $myDeps $name]} {
            error "Unknown target: $name\nKnown targets are: [dict keys $myDeps]"
        }
        set dict [dict get $myDeps $name]
        list $self [dict get $dict kind] $name
    }
    method {target exists} name {dict exists $myDeps $name}
    method {target get} name {dict get $myDeps $name}
    
    method {target lambda} {target script} {
        set targetNS [$self runtime typename]::Snit_inst1
        lassign [$self target extra-args $target] vars values
        set preamble "::variable options;\n"
        foreach vspec [$self misc get variable] {
            append preamble "::variable [lindex $vspec 1];\n"
        }
        list apply [list [list self selfns target {*}$vars] \
                        $preamble$script $targetNS] \
            [$self runtime instance] $selfns $target {*}$values
    }

    method {target extra-args} target {
        set vars []
        set vals []
        foreach {var val} [dict-default [dict get $myDeps $target] values] {
            lappend vars $var
            lappend vals $val
        }
        list $vars $vals
    }

    # Below defines [$scope target check $targetName],
    # [$scope target action $targetName] and so on.
    foreach key $knownKeys {
        method [list target $key] name [string map [list @KEY@ $key ] {
            dict-default [dict get $myDeps $name] @KEY@ []
        }]
    }

    method {target depends} name {
        dict-default [dict get $myDeps $name] depends []
    }

    method {target lappend depends} {name args} {
        if {![dict exists $myDeps $name]} {
            error "No such target: $name"
        }
        dict update myDeps $name target {
            dict update target depends listVar {
                lappend listVar {*}$args
            }
        }
    }

    method {extern exists} name {
        dict exists $myExtern $name
    }
    method {extern get} name {
        dict get $myExtern $name
    }
    method {extern add} {name dict {asName ""}} {
        dict set myExtern $name $dict
        if {$asName ne ""} {
            dict set myExtern $asName $dict
        }
        set dict
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

    variable myImportList []
    method {import add} {patternList fromFile fileNS} {
        
        # Verify typos of import patterns
        set testNS ${selfns}::comptype
        foreach pat $patternList {
            namespace eval $testNS \
                [list namespace import ${fileNS}::$pat]
            if {$pat ne "*"} {
                set origCmd [namespace eval $testNS \
                                [list namespace which -command $pat]]
                if {$origCmd eq ""} {
                    error "Can't import $pat from namespace $fileNS file $fromFile"
                }
            }
        }

        lappend myImportList [list $patternList $fromFile $fileNS]
    }
    method {import list} {} {set myImportList}
    method {import ns-list} {} {
        struct::list mapfor i $myImportList {lindex $i end}
    }

    variable myMisc [dict create method [] proc []]
    method {misc add} {kind name body} {
        dict set myMisc $kind $name $body
    }
    method {misc get} {kind {default ""}} {
        dict values [dict-default $myMisc $kind $default]
    }

    method {target subst} {target string} {
        string map [$self var-map $target] $string
    }

    method var-map target {
        set depList []
        foreach d [$self target depends $target] {
            lassign $d scope kind dep
            lappend depList $dep
        }
        list \
            \$@ $target \
            \$< [string trim [lindex $depList 0]] \
            \$^ [lrange $depList 0 end]
    }

    typemethod ensure-instance ns {
        if {[info commands ${ns}::instance] ne ""} return
        ${ns}::runtime create ${ns}::instance
        namespace eval ${ns}::runtime::Snit_inst1\
            [list namespace path ${ns}::runtime]
        return ${ns}::instance
    }

    method genscript args {
        set script [__EXPAND [string trimleft $ourTypeTemplate] \
                        %TYPENAME% [$self runtime typename] \
                        %METHODS% [join [$self misc get method] \n] \
                        %PROCS% [join [$self misc get proc] \n] \
                        %DEPS% [$self deps] \
                        %OPTIONS% [join [$self misc get option] \n] \
                        %VARIABLES% [join [$self misc get variable] \n]
                       ]

        foreach spec [$self import list] {
            lassign $spec pattern fromFile gotNS
            if {$gotNS ne ""} {
                append script [list namespace eval [$self runtime typename] \
                    [list apply {{ns args} {
                        foreach pat $args {
                            namespace import ${ns}::$pat
                        }
                    }} $gotNS {*}$pattern]]\n
            }
        }

        append script [list $type ensure-instance $selfns]\n

        set script
    }

    proc __EXPAND {template args} {
        string map $args $template
    }

    typevariable ourTypeTemplate {
        snit::type %TYPENAME% {

            typevariable ourDeps {
                %DEPS%
            }
            #-----------------------------

            %OPTIONS%
            %VARIABLES%
            %METHODS%
            %PROCS%

            method selfns {} {return $selfns}
            method {target list} {} {dict keys $ourDeps}
        }
    }
}
