#!/usr/bin/tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

# import * from net-utils.tcl

namespace eval net-utils {

    proc domain-name-of hostname {
        regsub {^[^.]+\.} $hostname {}
    }

    namespace export *
    namespace current
}
