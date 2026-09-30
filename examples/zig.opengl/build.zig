const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zipper.opengl",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    // glfw-zig
    const glfw = b.dependency("zglfw", .{});
    exe.root_module.addImport("glfw", glfw.module("glfw"));
    exe.root_module.linkSystemLibrary("glfw", .{});
    // exe.root_module.linkLibrary(glfw.artifact("glfw"));

    // OpenGL bindings: zigglgen
    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.0",
        .profile = .core,
        .extensions = &.{},
    });
    exe.root_module.addImport("gl", gl_bindings);

    // Framerecorder
    const framerecorder = b.dependency("framerecorder", .{});
    exe.root_module.addImport("framerecorder", framerecorder.module("root"));

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the example");
    run_step.dependOn(&run_cmd.step);
}
