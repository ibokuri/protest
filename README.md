# Protest

<a href="https://github.com/ibokuri/protest/releases/latest"><img alt="Version" src="https://img.shields.io/github/v/release/ibokuri/protest?include_prereleases&label=version"></a>
<a href="https://github.com/ibokuri/protest/actions/workflows/test.yml"><img alt="Build status" src="https://img.shields.io/github/actions/workflow/status/ibokuri/protest/test.yml?branch=main" /></a>
<a href="https://ziglang.org/download"><img alt="Zig" src="https://img.shields.io/badge/zig-master-fd9930.svg"></a>
<a href="https://github.com/ibokuri/protest/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue"></a>

Protest is a set of modules for testing and validating Zig code.

## [`require`](https://ibokuri.github.io/protest/#A;protest:require) Module

The `require` module some provides helpful functions to help you write tests.

- Descriptive and easy to read failure descriptions.
- Simplified testing code.
- Requirements can be annotated with a custom message.

```zig
const require = @import("protest").require;

test {
    // Require equality.
    try require.equalf(123, 123, "They should be {s}", .{"equal"});

    // Require inequality.
    try require.notEqualf(123, 456, "They should not be {s}", .{"equal"});

    // Require that `value` is not null.
    try require.notNull(value);

    // Since `value` cannot be null, safely unwrap it and check its payload.
    try require.equal("Foobar", value.?);
}
```

```
run test: error: 'test_0' failed:

        Error:          Not equal:
                        expected: "Foobar"
                        actual:   "Barfoo"
        Error Trace:

/tmp/example/src/main.zig:14:5: 0x1048a5027 in test_0 (test)
    try require.equal("Foobar", value.?);
    ^
```

## Installation

1. Declare Protest as a dependency in `build.zig.zon`:

    ```diff
    .{
        .name = "my-project",
        .version = "1.0.0",
        .paths = .{""},
        .dependencies = .{
    +       .protest = .{
    +           .url = "https://github.com/ibokuri/protest/archive/<COMMIT>.tar.gz",
    +       },
        },
    }
    ```

2. Add Protest as a module in `build.zig`:

    ```diff
    const std = @import("std");

    pub fn build(b: *std.Build) void {
        const target = b.standardTargetOptions(.{});
        const optimize = b.standardOptimizeOption(.{});

    +   const opts = .{ .target = target, .optimize = optimize };
    +   const protest_mod = b.dependency("protest", opts).module("protest");

        const tests = b.addTest(.{
            .root_source_file = .{ .path = "src/main.zig" },
            .target = target,
            .optimize = optimize,
        });

    +   tests.addModule("protest", protest_mod);

        ...
    }
    ```

3. Obtain Protest's package hash:

    ```
    $ zig build --fetch
    my-project/build.zig.zon:7:20: error: url field is missing corresponding hash field
            .url = "https://github.com/ibokuri/protest/archive/<COMMIT>.tar.gz",
                   ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    note: expected .hash = "<HASH>",
    ```

4. Update `build.zig.zon` with Protest's package hash:

    ```diff
    .{
        .name = "my-project",
        .version = "1.0.0",
        .paths = .{""},
        .dependencies = .{
            .protest = .{
                .url = "https://github.com/ibokuri/protest/archive/<COMMIT>.tar.gz",
    +           .hash = "<HASH>",
            },
        },
    }
    ```

