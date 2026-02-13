# Usage Guide

TclTaskRunner (ttr) can be used as both a command-line tool and a library for other Tcl scripts.

## Command-Line Usage

When running `TclTaskRunner.tcl`, the basic format is as follows:

```bash
TclTaskRunner.tcl [options] [taskfile.tcltask] [key=value ...] [target_or_method] [args...]
```

### Argument Interpretation
1.  **System Options**: `--dry-run`, `--debug`, `--silent`, etc. These control ttr's own behavior.
2.  **Task File**: The `.tcltask` file to load. If omitted, it looks for `main.tcltask`.
3.  **Task Options (`key=value`)**: Passes values to variables defined as `option -key` within the `.tcltask` file.
4.  **Target or Method**: 
    - The name of the `target` you want to execute.
    - Or the name of a `method` defined within the `.tcltask`.
    - If omitted, the `default target` is executed.

### Example
Using `tests/080_option/main.tcltask` as an example:

```tcl
option -name -default foo
method clean {} { ... }
target all { ... }
```

Calling this file:
- `ttr main.tcltask`: Executes the `all` target with `-name foo`.
- `ttr main.tcltask name=bar`: Executes the `all` target with `-name bar`.
- `ttr main.tcltask clean`: Executes the `clean` method.

## Usage as a Library

To control ttr from your own Tcl script:

### 1. Initialization and Loading
```tcl
source TclTaskRunner.tcl

# Create an instance
TclTaskRunner dep -debug 0 -silent 1

# Load a task file
set taskset [dep use path/to/my.tcltask name=value]
```

### 2. Executing Tasks
```tcl
# Execute the default target
dep run @my

# Execute a specific target
dep run @my mytarget

# Execute a method
dep run @my mymethod arg1 arg2
```

### 3. Using the Registry
All loaded task sets are registered in the registry with a name prefixed by `@` based on the file's base name (e.g., `@my`).

- **In Dependencies**: You can specify `dependsTasks @my` to depend on the default target of another task set.
- **Retrieving Objects**: You can retrieve and manipulate task set objects directly: `set obj [dep registry get @my]`.

## .tcltask Structure and Exposure
Elements defined within a `.tcltask` are exposed externally as follows:

- **`target`**: Becomes a unit of execution that can be specified in CLI arguments or `dep run`.
- **`option`**: Can be set via CLI `key=value` arguments or during `dep use`. Referenced internally as `$options(-key)`.
- **`method`**: Defined as an object method and can be called by name from the outside, similar to a `target`.
- **`proc`**: Becomes a private procedure valid only within that task set.
- **`variable`**: A shared variable within the task set.
