const std = @import("std");
const ImageData = @import("ImageData.zig").ImageData;

var allocator: std.mem.Allocator = undefined;
var file_prefix: []const u8 = undefined;
var foldername: []const u8 = undefined;

const max_threads = 4;
var payloads: std.array_list.Managed(ImageData) = undefined;
var thread_pool: [max_threads]std.Thread = undefined;

pub fn init(alloc: std.mem.Allocator, filename: []const u8, folder: []const u8) !void {
    allocator = alloc;
    file_prefix = filename;
    foldername = folder;
    payloads = std.array_list.Managed(ImageData).init(allocator);
    _ = try std.Thread.spawn(.{}, sendPayloads, .{});
}

pub fn deinit() void {
    // for (payloads.items) |b| b.deinit();
    payloads.deinit();
    // for (thread_pool.items) |t| t.detach();
    // thread_pool.deinit();
}

pub fn putPixels(pixels: []u8, width: i32, height: i32, frame: u32) !void {
    const payload = ImageData{
        .frame = frame,
        .ext = "png",
        .filename = file_prefix,
        .foldername = foldername,
        .data = pixels,
        .width = width,
        .height = height,
    };
    try sendPayload(payload);
    // try payloads.append(payload);
    // thread_pool[@mod(frame, max_threads)]
    // _ = try std.Thread.spawn(.{}, sendPayload, .{payload});
    // try buffers[@mod(frame, max_threads)].append(payload);
}

pub fn sendPayload(payload: ImageData) !void {
    var json_writer: std.io.Writer.Allocating = .init(allocator);
    defer json_writer.deinit();
    try std.json.Stringify.value(payload, .{
        .whitespace = .indent_1,
    }, &json_writer.writer);

    var response: std.Io.Writer.Allocating = .init(allocator);
    defer response.deinit();

    var http_client = std.http.Client{
        .allocator = std.heap.page_allocator,
    };
    defer http_client.deinit();
    const request = try http_client.fetch(.{
        .method = .POST,
        .location = .{
            .url = "http://127.0.0.1:8000/api/imageseq",
        },
        .payload = json_writer.written(),
        .response_writer = &response.writer,
    });
    if (request.status != .ok) {
        std.debug.print("[ERROR] Failed to send request: {any}\n", .{request.status});
    }
}

fn sendPayloads() !void {
    while (true) {
        while (payloads.pop()) |next| {
            const thread = try std.Thread.spawn(.{}, sendPayload, .{next});
            thread.join();
        }
    }
}
