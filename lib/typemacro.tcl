#!/usr/bin/env tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

snit::macro ::TclTaskRunner::enum_dict args {
    set dict [dict create]
    foreach n $args {
        dict set dict $n [incr i]
    }
    set dict
}

snit::macro ::TclTaskRunner::keyword_dict args {
    set dict [dict create]
    foreach n $args {
        dict set dict $n $n
    }
    set dict
}
