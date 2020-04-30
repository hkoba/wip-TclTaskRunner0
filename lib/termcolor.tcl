#!/usr/bin/tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

if {[catch {
    package require term::ansi::code::attr
    package require term::ansi::code::ctrl
    namespace eval ::TclTaskRunner {
        ::variable ourAlertColor \
            [list [term::ansi::code::ctrl::sda [term::ansi::code::attr::bgred]] \
                 [term::ansi::code::ctrl::sda [term::ansi::code::attr::bgdefault]]
                ]
    }
}]} {
    namespace eval ::TclTaskRunner {
        ::variable ourAlertColor []
    }
}

snit::typemethod TclTaskRunner alert message {
    lassign $::TclTaskRunner::ourAlertColor prefix suffix
    puts stderr \n\n-----------\n
    puts stderr $prefix$message$suffix
}
