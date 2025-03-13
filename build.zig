const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("root", .{
        .root_source_file = b.path("./zig/root.zig"),
    });

    const exe = b.addExecutable(.{
        .root_source_file = b.path("zig/main.zig"),
        .name = "zipper",
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("tokamak", b.dependency("tokamak", .{}).module("tokamak"));
    b.installArtifact(exe);

    const zstbi = b.dependency("zstbi", .{});
    exe.root_module.addImport("zstbi", zstbi.module("root"));

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
