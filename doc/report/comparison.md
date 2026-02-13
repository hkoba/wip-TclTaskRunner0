# Task Runner Comparison Report: TclTaskRunner vs Others

This report compares TclTaskRunner (ttr) with other widely used task runners (Make, Taskfile, Rake, Just, etc.) and analyzes its design philosophy, strengths, and weaknesses.

## Comparison Table

| Feature | TclTaskRunner (ttr) | GNU Make | Taskfile (go-task) | Rake / Invoke |
| :--- | :--- | :--- | :--- | :--- |
| **Base Language** | Tcl | Custom / Shell | YAML / Shell | Ruby / Python |
| **Dependency Criteria** | File mtime & **Check Script** | File mtime only | File mtime / Check | Programming Logic |
| **Dry-run Support** | Strong (Language integrated) | Limited (Per command) | None (Shell dependent) | Depends on language |
| **Extensibility** | Extremely high (Metaprogramming) | Low (Macros only) | Medium (Plugins/Templates)| High (Full language) |
| **Ease of Learning** | Medium (Requires Tcl knowledge) | Low (Unique syntax) | High (YAML) | Medium (Requires lang knowledge) |

## Strengths of TclTaskRunner

### 1. Advanced Abstraction of "State"
While Make primarily relies on "whether a file exists" or "whether a file is new," ttr abstracts the execution result of a `check` script as `mtime`.
- If `check` returns false, it is treated as `-Inf` (infinite past), causing the task to be re-executed even if dependent files exist.
- This allows for managing **non-file states** (e.g., package installation status, OS configuration values, existence of DB records) using the same simple logic as a Makefile.

### 2. Language-Level Dry-run (`-n`) Integration
One of ttr's greatest strengths is its built-in dry-run support through markers/commands like `**` and `RUN`.
- Most tools only interpret shell commands as strings in dry-run mode, but ttr traps execution using Tcl's `interp alias`.
- Since Tcl's `exec` takes arguments as-is, commands including complex quoting and redirections can be safely and accurately simulated in dry-run mode.

### 3. Powerful Metaprogramming and Isolation
`.tcltask` files are converted into `snit::type` (classes) at runtime.
- Each task set is treated as an independent object with an isolated namespace.
- Leveraging Tcl's `interp` features, it provides full control over the parsing and execution of user code.

## Weaknesses of TclTaskRunner

### 1. Ecosystem and Adoption
- Compared to modern languages like Python, Go, or Node.js, Tcl has a smaller ecosystem of libraries and a smaller developer community.
- There is no native integration (like plugins) for modern build tools (npm, Cargo, etc.), requiring users to call `exec` manually.

### 2. Syntax Familiarity
- Compared to YAML-based Taskfiles or the familiar Makefile, Tcl's syntax (especially its use of brackets) is unique and may present a steeper learning curve for new users.

## Conclusion

**TclTaskRunner is best for:**
- OS system administration and configuration management tasks that frequently handle non-file "states."
- Infrastructure setup tasks that involve many destructive operations and require strict dry-run verification.
- Large projects where building a custom DSL to encapsulate complex build logic is beneficial.

**Other tools are better for:**
- Simple compilation and linking projects (Make).
- Projects where the team is comfortable with YAML and prefers configuration simplicity over scripting flexibility (Taskfile).
- Projects deeply tied to a specific language ecosystem like Ruby or Python (Rake, Invoke).
