const std = @import("std");
const glfw = @import("glfw");
const gl = @import("gl");
const fr = @import("framerecorder");

const l = std.log.scoped(.@"opengl-example");

var is_recording = false;

fn getProcAddress(prefixed_name: [*:0]const u8) ?gl.PROC {
    return @ptrCast(@alignCast(glfw.getProcAddress(std.mem.span(
        prefixed_name,
    ))));
}

fn keyCallback(
    window: *glfw.Window,
    key: c_int,
    scancode: c_int,
    action: c_int,
    mods: c_int,
) callconv(.c) void {
    _ = window;
    _ = scancode;
    _ = mods;
    switch (key) {
        glfw.KeyR => {
            if (action != glfw.Release) return;
            l.info("{s} recording\n", .{
                if (is_recording) "Stopped" else "Started",
            });
            is_recording = !is_recording;
        },
        else => {},
    }
}

pub fn main(init: std.process.Init) !void {
    var arena = init.arena.allocator();

    const width = 720;
    const height = 720;
    try glfw.init();
    const window = try glfw.createWindow(
        width,
        height,
        "framerecorder-zig.opengl",
        null,
        null,
    );
    defer glfw.destroyWindow(window);
    glfw.makeContextCurrent(window);

    var procs: gl.ProcTable = undefined;

    if (!procs.init(getProcAddress)) return error.InitFailed;
    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);

    var time: f32 = 0;
    var frame: u32 = 0;
    var r: f32 = 0.0;
    var g: f32 = 0.0;
    var b: f32 = 0.0;

    const size = @as(usize, @intCast(width)) *
        @as(usize, @intCast(height)) *
        4;
    var pixels: []u8 = try arena.alloc(
        u8,
        size,
    );
    try fr.init(arena, "zig.opengl", "examples");
    defer fr.deinit();

    _ = glfw.setKeyCallback(window, keyCallback);

    while (!glfw.windowShouldClose(window)) {
        glfw.pollEvents();

        gl.ClearColor(r, g, b, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        glfw.swapBuffers(window);

        if (is_recording) {
            l.info("Saving frame {d:05}...\n", .{frame});
            gl.ReadPixels(
                0,
                0,
                width,
                height,
                gl.RGBA,
                gl.UNSIGNED_BYTE,
                @ptrCast(pixels[0..]),
            );
            try fr.storePixels(
                init.io,
                pixels,
                width,
                height,
                frame,
            );
            frame += 1;
        }

        r = std.math.sin(time * 0.2);
        g = std.math.cos(time * 0.3);
        b = std.math.tan(time * 0.01);

        time += 0.1;
    }
}
