# PLJS Configuration Options

PLJS provides configuration options that are available either with the `SET` command in Postgres, or by adding them to the `postgresql.conf` file.

## Runtime Options

| Setting                  | Description                                                                   | Default                        |
| ------------------------ | ----------------------------------------------------------------------------- | ------------------------------ |
| `pljs.execution_timeout` | Execution timeout in seconds before the JavaScript runtime is interrupted     | `300` (Range of `1`-`65536`)   |
| `pljs.memory_limit`      | Memory limit of the JavaScript engine in `MB`                                 | `512` (Range of `64`-`3096`)   |
| `pljs.start_proc`        | A function name to be called when the JavaScript engine is first initialized  |                                |
| `pljs.max_module_depth`  | Maximum recursion depth for nested `pljs.import()` / `pljs.require()` calls   | `512` (Range of `1`-`65536`)   |

## Limits that stop a function

When a function goes above `pljs.memory_limit`, QuickJS-ng raises an `InternalError` with the message `out of memory`. A function cannot catch an `InternalError` with `try`/`catch`: the error always stops the function and goes to Postgres. This is also true for the `InternalError` with the message `interrupted`, which stops a function when Postgres cancels the query (for example at `statement_timeout`).

When JavaScript recursion goes above the stack budget, QuickJS-ng raises a `RangeError` with the message `Maximum call stack size exceeded`. A function can catch this error. The stack budget is half of `max_stack_depth`, and at least 256 kB. `pljs_info()` shows it as `stack_size`.

## Hook Options

Hooks require superuser privileges to enable or configure. See [HOOKS.md](HOOKS.md) for details.

| Setting                  | Description                                                                   | Default |
| ------------------------ | ----------------------------------------------------------------------------- | ------- |
| `pljs.hooks_enabled`     | Enable PLJS executor hooks (superuser only)                                   | `false` |
| `pljs.hooks_max_depth`   | Maximum recursion depth for PLJS hooks (superuser only)                       | `5`     |

## Notes

### `pljs.execution_timeout`

The execution timeout GUC is only registered when PLJS is built with
`EXECUTION_TIMEOUT` defined. Without it, JavaScript functions may run
indefinitely — long-running or infinite loops will not be automatically
interrupted by PLJS. This is a deliberate design choice: the default build
relies on PostgreSQL's own `statement_timeout` for query-level timeouts and
on SIGINT (e.g. query cancellation) to interrupt JS execution, which the
runtime's interrupt handler does respect.

To enable per-JS-function timeouts, rebuild with `-DEXECUTION_TIMEOUT` and
set `pljs.execution_timeout` as needed.

### `pljs.modules` and `pljs.packages`

Modules loaded via `pljs.import()` and `pljs.require()` are stored in the
`pljs.modules` and `pljs.packages` tables. By design, any role with INSERT
or UPDATE on these tables can register code that will be loaded and executed
by any function calling `pljs.import()` or `pljs.require()`.

The default permissions restrict writes to the extension owner (typically
the superuser that ran `CREATE EXTENSION pljs`). **Do not grant write
access to these tables to untrusted roles.** Any user with that privilege
can effectively inject arbitrary JavaScript into other users' function
execution paths.

Read access is safe to grant — module source is not secret, and resolution
uses exact string match on `(path)` or `(package_name, package_version,
path)`, so there is no filesystem traversal surface.
