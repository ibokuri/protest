const std = @import("std");

const package_name = "protest";
const package_path = "src/protest.zig";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Package module.
    _ = b.addModule(
        package_name,
        .{ .root_source_file = b.path(package_path) },
    );

    // Tests
    {
        const test_step = b.step("test", "Run tests");
        const test_require_step = b.step("test-require", "Run require tests");

        const t_require = b.addTest(.{
            .name = "require test",
            .root_source_file = b.path("src/require.zig"),
            .target = target,
            .optimize = optimize,
        });
        test_require_step.dependOn(&b.addRunArtifact(t_require).step);
        test_step.dependOn(test_require_step);
    }

    // Documentation.
    {
        const docs_step = b.step("docs", "Build the project documentation");

        const doc_obj = b.addObject(.{
            .name = "docs",
            .root_source_file = b.path(package_path),
            .target = target,
            .optimize = optimize,
        });

        const install_docs = b.addInstallDirectory(.{
            .source_dir = doc_obj.getEmittedDocs(),
            .install_dir = .prefix,
            .install_subdir = "docs/protest",
        });
        docs_step.dependOn(&install_docs.step);
    }
}
