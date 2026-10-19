# PLJS Development

PLJS provides JavaScript functionality as a language extension for Postgres. It's implemented in `C` and built using `make` and a `C` compiler.

## Building

As long as pre-requisites are met, building can be as simple as running `make`:

```bash
make
```

and installation by running:

```bash
make install
```

Some specific packages and software need to be installed depending on the operating system in use:

### MacOS

- XCode (provides `clang`, `make`, and `git`)
- CMake (such as with `brew`)
- Postgres (such as with `brew`)

### Linux

- Postgres development packages
- `git`
- `gcc` (typically with `build-essential` or `development tools` depending on operating system)
- `make` (generally installed with the above packages)
- `cmake`

### QuickJS-ng

PLJS links the JavaScript engine, [QuickJS-ng](https://github.com/quickjs-ng/quickjs), statically into `pljs.so`. The engine source is the git submodule `deps/quickjs-ng`, pinned to one commit. `make` does these steps before it compiles PLJS:

1. If `deps/quickjs-ng` is empty, it runs `git submodule update --init deps/quickjs-ng`.
2. It configures QuickJS-ng with CMake in `deps/build/quickjs-ng`, outside the submodule, and builds the static library `libqjs.a` there.

The library is built with `-fPIC`, because `pljs.so` is a shared object, and with `-fvisibility=hidden`. The hidden visibility is necessary: the `postgres` binary exports functions that have the same names as internal QuickJS-ng functions (for example `unicode_normalize`). If `pljs.so` exported the QuickJS-ng symbols, the dynamic linker could bind a QuickJS-ng call to the Postgres function, and the backend would crash.

`make DEBUG=1` builds QuickJS-ng with debug information (`RelWithDebInfo`). `make` builds the library again only when a QuickJS-ng source file changes. Thus after a change of build options, run `make cleanquickjs` to remove the QuickJS-ng build, so that the next `make` builds it again.

To move to a newer QuickJS-ng, check out the new commit in `deps/quickjs-ng`, commit the submodule change, and run the tests. Some expected test output contains QuickJS-ng error messages and stack traces, so a new version can change it.

## Testing

PLJS uses Postgres' testing framework.

### Tests

Tests use Postgres' [regression testing framework](https://www.postgresql.org/docs/current/regress.html), thus running `make installcheck` after running `make install` will run the test suite and provide results. Tests live in the `sql` directory and are named according to their tests.

## File Naming Conventions

Files are named by function.

### Source

All source for the PLJS extension can be found in the `src` directory:

- `pljs.h` - Header file that defines functions and `structs`
- `pljs.c` - Main entry point for PLJS, including setup and teardown
- `cache.c` - Context and function caching
- `functions.c` - Functions available from PLV8
- `types.c` - Type conversion to/from Postgres/JavaScript
- `params.c` - Parameter management for Postgres

The JavaScript engine is in `deps/quickjs-ng` (see [QuickJS-ng](#quickjs-ng)).

### Tests

All tests live in the `sql` directory, and their expected results live in the `expected` directory.

Tests are named by the function that they test.

## Function Naming Conventions

Naming conventions for this project generally favor using `pljs_` as a prefix for functions that are not private (not marked `static`) in the project. `C` functions accessible from JavaScript are also prefixed with `pljs_` and marked as static, indicating their availability within the JavaScript engine.

A function scoped to `pljs.c`](../src/pljs.c)`:

```c
static Datum call_function(PG_FUNCTION_ARGS, pljs_context *context,
                           JSValueConst *argv);
```

A function available throughout the project:

```c
bool pljs_has_permission_to_execute(const char *signature);
```

A function available in JavaScript:

```c
static JSValue pljs_elog(JSContext *ctx, JSValueConst this, int argc, JSValueConst *argv);
```
