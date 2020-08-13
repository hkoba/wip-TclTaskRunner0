# -*- mode: tcl; tab-width: 4; coding: utf-8 -*-

namespace eval sed-utils {
    
    proc sed-insert-before {fn address content args} {
        ** exec sed {*}$args "${address}i $content" $fn
    }

    proc sed-append-after {fn address content args} {
        ** exec sed {*}$args "${address}a $content" $fn
    }

    proc sed-delete-at {fn address args} {
        ** exec sed {*}$args "${address}d" $fn
    }

    proc sed-apply-at {fn address command args} {
        ** exec sed {*}$args -e "$address $command" $fn
    }

    namespace export *

    namespace current
}
