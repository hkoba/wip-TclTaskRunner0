# TclTaskRunner (ttr)

[![test](https://github.com/hkoba/TclTaskRunner0/actions/workflows/test.yml/badge.svg)](https://github.com/hkoba/TclTaskRunner0/actions/workflows/test.yml)

A Make-like, dependency-driven task runner written in Tcl — designed for
*converging a machine into a desired state*, not only for building files.

## Why another task runner?

`make` decides whether a target is up to date solely from file existence
and timestamps. That is fine for compiling, but system administration
mostly deals with states that are not files: *is this package installed?
does this config line exist? is this service enabled?*

In ttr, every target may define a **`check` script** — an arbitrary Tcl
predicate. A target whose check returns false is treated as infinitely
old, so its `action` runs (after its dependencies are satisfied). This
generalizes make-style dependency resolution to arbitrary system states,
and makes re-runs naturally idempotent: once every check passes, running
the task file again does nothing.

## Highlights

- **check-based dependencies** — any Tcl predicate can drive the
  dependency graph, alongside classic file/timestamp dependencies.
- **Language-integrated dry-run** — destructive commands are marked with
  `**`; with `-n` they are printed instead of executed. Because
  redirections in Tcl's `exec` are plain arguments rather than shell
  syntax, even `>` redirects are dry-run safe.
- **Drift detection** — `--status` evaluates only the checks and reports
  each target as satisfied / needs-action, with diff-style exit codes
  (0/1/2) suitable for cron monitoring.
- **Incremental development** — a `.tcltask` file is compiled into a snit
  class; any `method` you define is directly callable from the command
  line, so you can build complex tasks piece by piece.
- **Parameterizable task sets** — `option` declarations take values from
  the command line (`key=value`), from a `.tcldict` sidecar file placed
  next to the task file, or from `use lib.tcltask as @name -opt value`
  multi-instantiation.

## Quick example

`main.tcltask`:

```tcl
#!/usr/bin/env TclTaskRunner.tcl

# A target is "satisfied" when its check returns true;
# otherwise its action runs (after its dependencies are satisfied).
default target greeting dependsTasks {workdir} check {
    file exists /tmp/work/greeting.txt
} action {
    ** exec date > /tmp/work/greeting.txt
}

target workdir check {
    file isdirectory /tmp/work
} action {
    ** file mkdir /tmp/work
}
```

```console
$ ./main.tcltask -n         # dry-run: show what would be done
file mkdir /tmp/work
exec date > /tmp/work/greeting.txt
$ ./main.tcltask            # converge to the desired state
file mkdir /tmp/work
exec date > /tmp/work/greeting.txt
$ ./main.tcltask            # already satisfied: does nothing
$ TclTaskRunner.tcl --status main.tcltask   # drift report
✔ @main#workdir
✔ @main#greeting
# 2 ok, 0 needs-action, 0 error
```

## Requirements

- Tcl 8.6 or 9.0
- [tcllib](https://core.tcl-lang.org/tcllib/) (snit, fileutil,
  struct::list, ...)

Fedora: `dnf install tcl tcllib` / Debian, Ubuntu: `apt install tcl tcllib`

## Install

Clone this repository and put `TclTaskRunner.tcl` on your `PATH` (it
finds its `lib/` directory relative to the resolved script location, so a
symlink from a bin directory works too). Task files can then use the
shebang line `#!/usr/bin/env TclTaskRunner.tcl` and be executed directly.

## Documentation

- [Usage guide](doc/usage.md) ([日本語](doc/usage.ja.md))
- [DSL reference](doc/dsl-reference.md) ([日本語](doc/dsl-reference.ja.md))
- [Architecture](doc/architecture.md) ([日本語](doc/architecture.ja.md))
- [Internals](doc/internals.md) ([日本語](doc/internals.ja.md))
- Japanese manual page: [ttr.ja.md](ttr.ja.md)
  ([HTML preview](https://htmlpreview.github.io/?https://github.com/hkoba/TclTaskRunner0/blob/master/ttr.ja.html))
- Working examples: [examples/](examples/)
- Motivation article (Japanese):
  <https://hkoba.hatenablog.com/entry/2020/05/16/233500>

## License

BSD 3-Clause. See [LICENSE](LICENSE).
