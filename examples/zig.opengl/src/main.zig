const std = @import("std");
const zglfw = @import("zglfw");
const gl = @import("gl");
const framerecorder = @import("framerecorder");

fn getProcAddress(prefixed_name: [*:0]const u8) ?gl.PROC {
    return @alignCast(zglfw.getProcAddress(std.mem.span(prefixed_name)));
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var procs: gl.ProcTable = undefined;

    const width = 720;
    const height = 720;
    try zglfw.init();
    const window = try zglfw.Window.create(width, height, "framerecorder-zig.opengl", null);
    defer window.destroy();
    zglfw.makeContextCurrent(window);

    if (!procs.init(getProcAddress)) return error.InitFailed;
    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);

    var time: f32 = 0;
    var frame: u32 = 0;
    var r: f32 = 0.0;
    var g: f32 = 0.0;
    var b: f32 = 0.0;

    var is_recording = false;
    var pixels: []u8 = try allocator.alloc(u8, @as(usize, @intCast(width)) * @as(usize, @intCast(height)) * 4);
    try framerecorder.init(allocator, "zig.opengl", "examples");
    defer framerecorder.deinit();

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        gl.ClearColor(r, g, b, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        if (window.getKey(.r) == .press) {
            is_recording = true;
        }
        if (window.getKey(.s) == .press) {
            is_recording = false;
        }

        zglfw.pollEvents();
        window.swapBuffers();

        if (is_recording) {
            std.debug.print("\nSaving frame {d}...", .{frame});
            gl.ReadPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, @ptrCast(pixels[0..]));
            try framerecorder.storePixelsThreaded(
                try allocator.dupe(u8, pixels),
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
