#!/usr/bin/tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

# import * from gcp-utils.tcl

package require http

# TODO: depends utils.tcl

namespace eval gcp-utils {

    proc gcp-instance-metadata attribute {
        gcp-metadata instance/attributes/$attribute
    }

    proc gcp-metadata location {

        set tok [http::geturl http://metadata/computeMetadata/v1/$location \
                     -headers [list Metadata-Flavor Google]]

        ::utils::scope_guard tok [list http::cleanup $tok]

        if {[http::ncode $tok] != 200} {

            error [list $location :: {*}[http::code $tok] ]

        } else {

            http::data $tok

        }
    }

    namespace export *
    namespace current
}

