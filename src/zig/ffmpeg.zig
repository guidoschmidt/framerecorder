const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // var child_process = std.process.Child.init(&[_][]const u8{ "ffmpeg", "-f rawvideo", "-video_size 1920x1920", "-pixel_format rgb24", "-framerate 1", "/dev/stdin", "output.mp4" }, allocator);
    var child_process = std.process.Child.init(&[_][]const u8{ "ffmpeg", "-f rawvideo", "-video_size 1920x1920", "-pixel_format rgb24", "-framerate 1", "pipe:4", "output.mp4" }, allocator);
    child_process.stdout_behavior = .Ignore;
    child_process.stdin_behavior = .Pipe;
    child_process.stderr_behavior = .Pipe;
    try child_process.spawn();
    std.debug.print("{any}", .{child_process.stdin.?});
    // _ = try child_process.stdin.?.write("");
    _ = try child_process.wait();
    // child_process.stdin.?.close();
    // const errbuf: []u8 = try allocator.alloc(u8, 1024);
    // var stderr_buf = std.ArrayListUnmanaged(u8).initBuffer(errbuf);
    // const outbuf: []u8 = try allocator.alloc(u8, 1024);
    // var stdout_buf = std.ArrayListUnmanaged(u8).initBuffer(outbuf);
    // try child_process.collectOutput(allocator, &stdout_buf, &stderr_buf, 1024);
    // std.debug.print("{s}", .{stdout_buf.items});
}
