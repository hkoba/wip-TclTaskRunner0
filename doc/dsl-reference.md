# DSL Reference

This document describes the commands and variables available in TclTaskRunner task definition files (`*.tcltask`).

## Core Commands

### `target`
Defines a new task.

```tcl
target name 
    check { ... } 
    action { ... } 
    dependsTasks { ... } 
    dependsFiles { ... } 
    values { var1 val1 var2 val2 ... }
```

- **check**: A script to verify if the task is already completed. If it returns true, the action is skipped.
    - To aid debugging, it can return a list in the format `[list $bool key1 val1 ...]` instead of just a boolean.
- **action**: The script to execute when the task is not fulfilled.
- **dependsTasks**: A list of other target names this task depends on.
- **dependsFiles**: A list of file paths this task depends on.
- **values** (alias: **let**): Defines local variables accessible within the `check` and `action` scripts.

### `target-file` (or `FILE`)
Defines a file-generating task. Similar to `target`, but the target name is treated as a file path.

### `default`
Specifies the default target for the file. Used as a prefix, e.g., `default target all ...`.

### `public`
Makes a target accessible from external task sets.

### `use`
Loads another `.tcltask` file.

```tcl
use other.tcltask as @other
```

By appending options (`-key value` pairs) after `as NAME`, you can create
multiple independent instances of the same task file, each with different
parameters.

```tcl
use vhost.tcltask as @blog -domain blog.example.jp -port 8080
use vhost.tcltask as @shop -domain shop.example.jp -port 8081

default target all dependsTasks {@blog @shop}
```

- A `use` with options requires an `as NAME` clause.
- Each instance is registered as `PARENT::NAME` (e.g. `@main::blog`) and
  appears under this name in `--status` output.
- Only options declared with `option -domain ...` in the used task file can
  be passed (see [Parameterizing Task Sets](#parameterizing-task-sets)).

### `import`
Imports commands from an external Tcl script.

```tcl
import {mycmd1 mycmd2} from utils.tcl
```

## Automatic Variables

Within `check` and `action` scripts, you can use automatic variables similar to Makefile:

- `$@`: The current target name.
- `$<`: The first dependency.
- `$^`: The list of all dependencies.
- `$self`: The current task set object.

## Utilities

### `**` (Dry-run Marker)
Place this before commands that perform destructive operations in an `action` script.

```tcl
** exec rm -rf /tmp/cache
```

- Normal mode: Executes the command.
- Dry-run mode (`-n`): Only prints the command to the screen.

### `RUN` / `=RUN`
Convenient shortcuts for executing external commands.

- **RUN**: Equivalent to `exec ... >@ stdout 2>@ stderr`. Prints both stdout and stderr while executing.
- **=RUN**: Equivalent to `exec ... 2>@ stderr`. Prints only stderr.
- Like `**`, these are skipped in dry-run mode.

### `IS_DRY_RUN`
Returns a boolean indicating whether the current execution is in dry-run mode (`-n`).

## Extensions to Standard Tcl
Since `.tcltask` files are converted into `snit::type`, you can use the following commands to define task set-specific elements:

- `variable`: Shared variables within the task set.
- `proc`: Private procedures within the task set.
- `option`: Externally configurable options.
- `method`: Publicly callable methods.

## Parameterizing Task Sets

A task file can be parameterized with `option` declarations, referenced as
`$options(-key)` inside `check` and `action` scripts. Values come from three
sources; later ones win:

1. `option -key DEFAULT` — the declared default
2. A `.tcldict` sidecar file placed next to the task file
3. Runtime arguments — `key=value` on the command line, or
   `use ... as @x -key value`

### The `.tcldict` Sidecar File

When loading `foo.tcltask`, ttr automatically reads `foo.tcldict` from the
same directory (if it exists) as option values. The format is a plain Tcl
dict (`key value` pairs).

```tcl
# foo.tcldict
name baz
content {Lorem ipsum dolor sit amet}
```

### The Symlink Instantiation Pattern

Given a generic task `lib/lib.tcltask`, a symlink
`foo.tcltask -> lib/lib.tcltask` with a `foo.tcldict` beside it runs the
same task body with site-specific parameters (see `tests/090_option_file/`
for a working example).

The recommended convention: keep the generic task body in your repository,
and put host-specific values at the deployment site (e.g. a symlink plus
`.tcldict` under `/etc/xxx.d/tasks/`). Operators then invoke tasks with no
arguments, and command-line `key=value` stays reserved for one-off
overrides — generic, reusable tasks without operational clutter.

To create multiple instances from within a single task file, use
`use ... as @NAME -key value` instead of symlinks (see [`use`](#use)).

### Option Type Validation

`option` accepts snit validation types; invalid values fail before anything
runs.

```tcl
option -name -default foo -type {snit::enum -values {foo bar baz}}
```

The option values effectively applied to each task set are shown in the
header lines of `--status` output (`# @NAME effective options: ...`).
