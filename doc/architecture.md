# TclTaskRunner Architecture

TclTaskRunner (ttr) is a highly extensible task runner that leverages the powerful metaprogramming capabilities of Tcl.

## System Overview

The system consists of five primary components:

1.  **Controller (TclTaskRunner.tcl)**
    - Parses CLI arguments and initializes the environment.
    - Orchestrates the execution flow by combining other components.

2.  **Registry (TaskSetRegistry)**
    - Manages loaded task definition files (`*.tcltask`).
    - Maps file paths to logical task set names.

3.  **Builder (TaskSetBuilder)**
    - Parses `.tcltask` files.
    - Evaluates DSL in an isolated interpreter.
    - Dynamically generates (compiles) executable `snit::type` (classes) from task definitions.

4.  **Definition Object (TaskSetDefinition)**
    - Holds the state and metadata of individual task sets.
    - Contains a dynamically generated "runtime instance" that provides the execution environment for `proc` and `variable` defined in the DSL.

5.  **Execution Context (RunContext)**
    - Builds the dependency graph and performs circular dependency checks.
    - Determines if a target needs updating based on timestamps (actual file mtime or the result of a `check` script).
    - Executes tasks (Action) and verifies the result (Post-check).

## Execution Flow

1.  **Load**: `TaskSetBuilder` reads a `.tcltask` file, evaluates the DSL, and collects target information.
2.  **Compile**: Generates a `snit::type` based on the collected information and defines it in the Tcl interpreter.
3.  **Analyze**: `RunContext` recursively traverses dependencies starting from the specified target.
4.  **Evaluate**: Determines if a target is "outdated" or "unfulfilled" by comparing the `check` script's return value or file `mtime`.
5.  **Execute**: Runs the `action` if necessary and confirms success with a final `check`.

## Abstraction of State Management

The most significant feature of ttr is its **abstraction of "fulfilled state" as "time (mtime)"**.

- **Files**: The value returned by `file mtime`.
- **Tasks**:
    - If `check` returns true → Current time (always up-to-date).
    - If `check` returns false → `-Inf` (infinite past, always needs update).

This abstraction allows ttr to process dependencies involving both files and abstract tasks using a single, consistent comparison logic.
