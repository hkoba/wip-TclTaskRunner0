# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

namespace eval sed-utils {
    
    proc sed-insert-before {fn lineNo content args} {
        exec sed {*}$args "${lineNo}i $content" $fn
    }

    proc sed-append-after {fn lineNo content args} {
        exec sed {*}$args "${lineNo}a $content" $fn
    }

    proc sed-delete-at {fn lineNo args} {
        exec sed {*}$args "${lineNo}d" $fn
    }

    proc sed-apply-at {fn lineNo command args} {
        exec sed {*}$args -e "$lineNo $command" $fn
    }

    namespace export *

    namespace current
}
