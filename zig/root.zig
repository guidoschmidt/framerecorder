const std = @import("std");
const ImageData = @import("main.zig").ImageData;

var allocator: std.mem.Allocator = undefined;
var file_prefix: []const u8 = undefined;
var foldername: []const u8 = undefined;

const max_threads = 8;
var buffers: [max_threads]std.ArrayList(ImageData) = undefined;
var background_threads: std.ArrayList(std.Thread) = undefined;

pub fn init(alloc: std.mem.Allocator, filename: []const u8, folder: []const u8) !void {
    allocator = alloc;
    file_prefix = filename;
    foldername = folder;
    background_threads = std.ArrayList(std.Thread).init(allocator);
    for (0..max_threads) |i| {
        buffers[i] = std.ArrayList(ImageData).init(allocator);
        const t = try std.Thread.spawn(.{}, sendPayloads, .{i});
        try background_threads.append(t);
    }
}

pub fn deinit() void {
    for (buffers) |b| b.deinit();
    for (background_threads.items) |t| t.detach();
}

pub fn putPixels(pixels: []u8, width: i32, height: i32, frame: usize) !void {
    const payload = ImageData{
        .frame_num = frame,
        .ext = "png",
        .filename = file_prefix,
        .foldername = foldername,
        .data = pixels,
        .width = width,
        .height = height,
    };
        _ = try std.Thread.spawn(.{}, sendPayload, .{i});
    // try buffers[@mod(frame, max_threads)].append(payload);
}

fn sendPoy

fn sendPayloads(buffer_idx: usize) !void {
    while (true) {
        if (buffers[buffer_idx].items.len == 0) continue;
        const payload = buffers[buffer_idx].pop();
        std.debug.print("\n>>> Sending {s} #{d}", .{ payload.filename, payload.frame_num });

        var string_stream = std.ArrayList(u8).init(allocator);
        defer string_stream.deinit();
        try std.json.stringify(payload, .{}, string_stream.writer());

        var body = std.ArrayList(u8).init(allocator);
        defer body.deinit();

        var http_client = std.http.Client{ .allocator = allocator };
        defer http_client.deinit();
        const request = try http_client.fetch(.{
            .method = .PUT,
            .location = .{ .url = "http://127.0.0.1:8000/pixels" },
            .response_storage = .{
                .dynamic = &body,
            },
            .payload = string_stream.items,
        });
        if (request.status != .ok) {
            std.debug.print("\nError on sending request: {any}", .{request.status});
        }
    }
}
