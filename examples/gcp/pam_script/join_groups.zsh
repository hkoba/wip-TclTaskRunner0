#!/bin/zsh

emulate -L zsh

set -e

binDir=$(cd $0:h; print $PWD)
driver=$binDir/PAM_Group.pm
groupListFn=/etc/ssri/basic_groups

function x {
    if (($#o_dryrun)); then
        print -R '#' ${(q-)argv}
    fi
    if (($#o_dryrun)); then
        return;
    fi
    "$@"
}

o_dryrun=()
zparseopts -D -K \
           n=o_dryrun

# XXX: $groupListFn は zsh 側で cat しても良かったかも.
# dry-run で足されるグループが見えるのはメリット
# わざわざファイルを作らなくてもドライバーの挙動を試せるのもメリット

x exec $driver do_update $groupListFn
