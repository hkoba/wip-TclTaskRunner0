# Implementation Details

This document explains the internal implementation techniques used in TclTaskRunner.

## Dynamic Class Generation (Builder)

TclTaskRunner does not perform static parsing; it "compiles" the DSL at runtime using Tcl's own capabilities.

1.  **Isolation**: Evaluates the `.tcltask` in a clean interpreter created via `interp create`.
2.  **Trapping**: Uses `interp alias` to redirect DSL commands (like `target`) to methods of the `TaskSetBuilder` class. This safely collects user definitions.
3.  **Template Expansion**: Injects the collected information into a `snit::type` template to create a new class definition script.
4.  **Dynamic Definition**: Evaluates that script using `uplevel #0` to define the new class in the global namespace.

## Runtime Context

The generated class instances are managed by `RunContext`.

### Dual Snit Object Structure
- `TaskSetDefinition` instance: Holds metadata and serves as the interface for the Builder.
- `...::runtime` instance: An isolated environment for executing actual user-defined code (`proc`, `variable`).

This dual structure allows for free-form Tcl code within the DSL while maintaining system-level management.

## Worker Interpreter Synchronization (Worker Sync)

ttr typically executes tasks in a "worker interpreter" isolated from the main interpreter (when `-isolate yes` is set).

### Namespace Synchronization
External Tcl namespaces brought in via the `import` command are automatically serialized and reconstructed in the worker interpreter during `worker sync` (using `ns-definition` in `lib/namespace-util.tcl`). This allows `proc` defined in external utilities (like `utils.tcl`) to be used transparently within tasks.

### Automatic Aliases
Utility commands like `RUN`, `=RUN`, `**`, and `IS_DRY_RUN` are set up as aliases in the worker interpreter that call back to the `RunContext` in the main interpreter. This ensures that code running in the worker correctly reflects the dry-run state.

## Update Logic (mtime Extremes)

Update detection in `RunContext` is based on the following numerical comparisons:

- `mtime(target) < max(mtime(depends))`: Dependency is newer; re-execute.
- `mtime(target) == -Inf`: Target is unfulfilled; execute.

By treating the `mtime` of a target as `-Inf` (infinite past) when its `check` script fails, ttr resolves complex dependencies without branching logic.

## Dry-run Mechanism

The `**` command is controlled by macros defined in `iomacro.tcl`. When the dry-run flag is true, `**` acts as a wrapper that logs the command to the output instead of executing it. Since Tcl's `exec` accepts redirections as arguments (evaluated inside `exec`), ttr can safely disable commands containing redirections without brittle string manipulation.
