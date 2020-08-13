# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

package require fileutil

namespace eval container-utils {

    # See: https://stackoverflow.com/a/20012536/1822437
    # How to determine if a process runs inside lxc/Docker?
    proc is-in-container {} {
        string equal [lindex [cgroup-of 1] 2] /
    }

    proc cgroup-of pid {
        split [string trim [::fileutil::cat /proc/$pid/cgroup]] :
    }

    namespace export *

    namespace current
}
