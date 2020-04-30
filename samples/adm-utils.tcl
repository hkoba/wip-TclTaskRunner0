# -*- coding: utf-8; mode: tcl -*-

proc check-user {user} {
    file-has ^${user}: /etc/passwd
}

proc check-group {group} {
    file-has ^${group}: /etc/group
}
