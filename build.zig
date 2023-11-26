const std = @import("std");

const package_name = "protest";
const package_path = "src/protest.zig";

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    _ = b.addModule(
        package_name,
        .{ .source_file = .{ .path = package_path } },
    );

    tests(b, target, mode);
    docs(b, target, mode);
}

fn tests(
    b: *std.build.Builder,
    target: std.zig.CrossTarget,
    mode: std.builtin.OptimizeMode,
) void {
    const test_step = b.step("test", "Run tests");

    // Allow a test filter to be specified.
    //
    // ## Example
    //
    // ```
    // $ zig build test -- "foo - bar"
    // ```
    if (b.args) |args| {
        switch (args.len) {
            0 => unreachable, // UNREACHABLE: b.args is null if no arguments are given.
            1 => {
                const cmd = b.addSystemCommand(&[_][]const u8{
                    "zig",
                    "test",
                    "--main-pkg-path",
                    "src/",
                    package_path,
                    "--test-filter",
                    args[0],
                });

                test_step.dependOn(&cmd.step);

                return;
            },
            else => |len| std.debug.panic("expected 1 argument, found {}", .{len}),
        }
    }

    const test_require_step = b.step("test-require", "Run require tests");

    // Configure tests.
    const t_require = b.addTest(.{
        .name = "require test",
        .root_source_file = .{ .path = "src/require.zig" },
        .target = target,
        .optimize = mode,
        .main_pkg_path = .{ .path = "src/" },
    });

    // Configure module-level test steps.
    test_require_step.dependOn(&b.addRunArtifact(t_require).step);

    // Configure top-level test step.
    test_step.dependOn(test_require_step);
}

fn docs(
    b: *std.build.Builder,
    target: std.zig.CrossTarget,
    mode: std.builtin.OptimizeMode,
) void {
    const docs_step = b.step("docs", "Build the project documentation");

    const doc_obj = b.addObject(.{
        .name = "docs",
        .root_source_file = .{ .path = package_path },
        .target = target,
        .optimize = mode,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = doc_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/protest",
    });
    docs_step.dependOn(&install_docs.step);
}
