# -*- coding: utf-8; mode: tcl -*-

namespace eval adm-utils {

proc check-user {user} {
    file-has ^${user}: /etc/passwd
}

proc check-group {group} {
    file-has ^${group}: /etc/group
}


proc query-systemctl {meth args} {
    set rc [catch {exec systemctl -q $meth {*}$args} result]
    list [expr {$rc == 0}] result $result
}

namespace export *

namespace current

}
