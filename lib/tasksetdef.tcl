#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

package require snit
package require fileutil

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
                                                  diag \
                                                  dependsTasks dependsFiles]]
    typemethod knownKey name {
        dict exists $ourKnownKeys $name
    }

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

    method dir {} {$self directory}
    method directory {} { file dirname $options(-file) }

    method {runtime typename} {} { return ${selfns}::runtime }
    method {runtime instance} {} { return ${selfns}::instance }
    method {runtime selfns} {} { return ${selfns} }
    method {runtime can} methodName {
        llength [${selfns}::instance info methods $methodName]
    }
    method {runtime invoke} args {
        ${selfns}::instance {*}$args
    }

    method dump {} {
        list deps $myDeps methods $myMethods procs $myProcs extern $myExtern
    }

    method deps {} {set myDeps}
    method {target spec} name {
        if {$name eq ""} {
            set name $options(-default)
        }
        set dict [dict get $myDeps $name]
        list $self [dict get $dict kind] $name
    }
    method {target exists} name {dict exists $myDeps $name}
    method {target get} name {dict get $myDeps $name}
    
    # Below defines [$scope target check $targetName],  [$scope target action $targetName] and so on.
    foreach key $knownKeys {
        method [list target $key] name [string map [list @KEY@ $key ] {
            dict-default [dict get $myDeps $name] @KEY@ []
        }]
    }

    method {target depends} name {
        dict-default [dict get $myDeps $name] depends []
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
