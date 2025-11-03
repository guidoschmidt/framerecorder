const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("root", .{
        .root_source_file = b.path("src/zig/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "framerecorder",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zig/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Dependencies
    const tokamak = b.dependency("tokamak", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport(
        "tokamak",
        tokamak.module("tokamak"),
    );

    const zstbi = b.dependency("zstbi", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zstbi", zstbi.module("root"));

    const ziggy_dep = b.dependency("ziggy", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("ziggy", ziggy_dep.module("ziggy"));

    // Installation
    b.installArtifact(exe);

    // Run
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
