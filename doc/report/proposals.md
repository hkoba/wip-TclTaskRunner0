# Proposals for TclTaskRunner Enhancements

This document proposes specific improvements and feature enhancements to evolve TclTaskRunner (ttr) into a more practical and powerful tool, building upon its current design.

## 1. Execution Engine Enhancements

### Parallel Execution Support
Currently, tasks are executed serially using Depth-First Search (DFS). Leverage Tcl's `Thread` package or the existing "worker interpreter" mechanism to enable parallel execution of tasks that have no dependencies on each other.
- **Expected Benefit**: Improve resource utilization and reduce execution time for large-scale builds or system updates.

### Result Caching
Introduce a mechanism to cache the results of `check` scripts in a file or a shared database (e.g., SQLite).
- **Expected Benefit**: Improve overall responsiveness by reducing the number of `check` executions that involve heavy commands or network operations.

## 2. DSL and Developer Experience (DX) Improvements

### Complete Unimplemented Features
Implement features currently marked as `error NIMPL` (Not Yet Implemented) in the codebase.
- **Dynamic Task Definition**: Implement `method define script` to allow programmatically adding new tasks from within a task set.
- **Target Configuration**: Allow setting attributes other than `depends` (e.g., timeout, retry count) in `target configure`.

### Precise Error Reporting
Currently, stack traces for errors in `action` or `check` scripts are standard Tcl traces. Improve this by mapping errors accurately to line numbers within the `.tcltask` file.
- **Expected Benefit**: Allow users to immediately identify exactly where they made a mistake in their task definitions.

### Shell Completion (Bash/Zsh)
Provide scripts for automatic completion of task set names and target names.
- **Expected Benefit**: Greatly improve CLI usability and reduce errors caused by typos.

## 3. Visualization and Debugging

### Dependency Graph Export
Implement a feature to export dependencies between loaded task sets in Graphviz (DOT) format.
- **Expected Benefit**: Provide a visual overview of complex projects, making debugging and refactoring easier.

### Structured Log Output
Add an option to output execution logs in a structured format like JSON.
- **Expected Benefit**: Facilitate integration with CI/CD pipelines and other monitoring tools.

## 4. Ecosystem and Reusability

### Standard Utility Library
Formalize and separate general-purpose procedures (like those in `examples/utils.tcl` and `sed-utils.tcl`) into an official `ttr-lib` package.
- **Expected Benefit**: Save users from having to reinvent the wheel for common OS operations and string manipulations.

### Module Management System
Consider a simple plugin/module management feature to download and `use` `.tcltask` files from external repositories.

## 5. Internal Architecture Optimization

### Potential Migration from Snit to TclOO
Standard TclOO is available in Tcl 8.6+. While Snit is very powerful, migrating to TclOO could be an option for reducing dependencies and improving performance in the future.
