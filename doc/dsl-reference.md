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
use other.tcltask as other
```

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
