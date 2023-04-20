# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

namespace eval sed-utils {
    
    proc sed-insert-before {fn address content args} {
        ** exec sed {*}$args -e [task-insert-before $address $content] $fn
    }

    proc task-insert-before {address content} {
        return "${address}i $content"
    }

    proc sed-append-after {fn address content args} {
        ** exec sed {*}$args -e [task-append-after  $address $content] $fn
    }

    proc task-append-after {address content} {
        return "${address}a $content"
    }

    proc sed-delete-at {fn address args} {
        ** exec sed {*}$args -e [task-delete-at $address] $fn
    }

    proc task-delete-at address {
        return "${address}d"
    }

    proc task-command {string} {
        return $string
    }

    proc sed-apply-at {fn address command args} {
        ** exec sed {*}$args -e "$address $command" $fn
    }

    proc dispatch-sed-tasks {fn taskList args} {
        set cmdList []
        foreach task $taskList {
            set rest [lassign $task op]
            set cmdName [namespace current]::task-$op
            if {[info commands $cmdName] eq ""} {
                error "Unknown sed task: $task"
            }
            lappend cmdList -e [$cmdName {*}$rest]
        }
        ** exec sed {*}$args {*}$cmdList $fn
    }

    namespace export *

    namespace current
}
