#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" ${1+"$@"}

cd [file dirname [info script]]

package require tcltest
namespace import ::tcltest::*

# tcltest >= 2.5 returns 1 if any test failed; older versions return "".
if {[set failed [runAllTests]] ne "" && $failed} {
    exit 1
}
