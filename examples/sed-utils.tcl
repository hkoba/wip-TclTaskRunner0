# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

namespace eval sed-utils {
    
    proc sed-insert-before {fn lineNo content args} {
        exec sed {*}$args "${lineNo}i $content" $fn
    }

    proc sed-append-after {fn lineNo content args} {
        exec sed {*}$args "${lineNo}a $content" $fn
    }

    namespace export *

    namespace current
}
