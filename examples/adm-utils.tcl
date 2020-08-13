# -*- coding: utf-8; mode: tcl -*-

namespace eval adm-utils {

proc check-user {user} {
    ::utils::file-has ^${user}: /etc/passwd
}

proc check-group {group} {
    ::utils::file-has ^${group}: /etc/group
}


proc passwd-uid-gid {{fn "/etc/passwd"}} {
    set dict [dict create]
    set fh [open $fn]
    while {[gets $fh line] >= 0} {
        lassign [split $line :] name x uid gid
        dict set dict $name [list $uid $gid]
    }
    close $fh
    set dict
}

proc query-systemctl {meth args} {
    set rc [catch {exec -ignorestderr systemctl -q $meth {*}$args} result]
    list [expr {$rc == 0}] result $result
}

namespace export *

namespace current

}
