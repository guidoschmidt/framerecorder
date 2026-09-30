const std = @import("std");
const tk = @import("tokamak");
const ImageServer = @import("ImageServer.zig");
const ImageData = @import("ImageData.zig");

const l = std.log.scoped(.framerecorder);

pub fn @"PUT /ffmpeg/:sequence/:frame"(
    sequence: []const u8,
    frame: u32,
    body: []const u8,
) !u32 {
    l.debug("Feed ffmpeg: {s}/#{d:04} {s}\n", .{
        sequence,
        frame,
        body,
    });
    // @TODO
    return 501;
}

pub fn @"PUT /imageseq/:sequence/:frame"(
    allocator: std.mem.Allocator,
    io: std.Io,
    sequence: []const u8,
    frame: u32,
    body: ImageData,
) !u32 {
    // l.debug("Store image sequence: {s}/#{d:04}\n", .{
    //     sequence,
    //     frame,
    // });
    ImageServer.storeImage(allocator, io, sequence, frame, body) catch |err| {
        l.err("{}", .{err});
        return 500;
    };
    return 200;
}
