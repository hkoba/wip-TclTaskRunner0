#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

snit::macro ::TclTaskRunner::io_util {} {
    method read_file {fn args} {
        set fh [open $fn]
        ::TclTaskRunner::scope_guard fh [list close $fh]
        read $fh
    }
}
