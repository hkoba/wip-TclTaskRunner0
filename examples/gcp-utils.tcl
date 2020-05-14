#!/usr/bin/tclsh
# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

# import * from gcp-utils.tcl

namespace eval gcp-utils {

    proc gcp-instance-metadata attribute {
        gcp-metadata instance/attributes/$attribute
    }

    proc gcp-metadata location {
        package require http
        set tok [http::geturl http://metadata/computeMetadata/v1/$location \
                     -headers [list Metadata-Flavor Google]]
        set data [http::data $tok]
        http::cleanup $tok
        set data
    }

    namespace export *
    namespace current
}

