const std = @import("std");
const tk = @import("tokamak");
const zstbi = @import("zstbi");
const ziggy = @import("ziggy");
const config = @import("Config.zig");

const Allocator = std.mem.Allocator;
const fs = std.fs;
const b64 = std.base64;
const b64_decoder = b64.standard.Decoder;

const l = std.log.scoped(.framerecorder);

const max_threads: u8 = 4;
var image_data_buffers: [max_threads]std.array_list.Managed(ImageData) = undefined;
var storage_threads: std.array_list.Managed(std.Thread) = undefined;

const ImageDataFormat = enum(u3) {
    RAW,
    DATA_URL,
};

pub const ImageData = struct {
    frame: u32,
    width: i32,
    height: i32,
    foldername: []const u8,
    filename: []const u8,
    ext: []const u8,
    data_format: ImageDataFormat = .RAW,
    data: []u8,

    pub fn format(self: ImageData, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("\nformat: {t}\nframe: {d}\nsize: {d} × {d}\nlocation: {s}/{s} [.{s}]", .{
            self.data_format,
            self.frame,
            self.width,
            self.height,
            self.foldername,
            self.filename,
            self.ext,
        });
    }
};

fn encodeVideo(allocator: Allocator, bytes: []const u8) !void {
    var child_process = std.process.Child.init(&[_][]const u8{
        "ffmpeg",
        "-f rawvideo",
        "-video_size 1920x1920",
        "-pixel_format rgb24",
        "-framerate 1",
        "/dev/stdin",
        "output.mp4",
    }, allocator);
    child_process.stdout_behavior = .Pipe;
    child_process.stdin_behavior = .Pipe;
    child_process.stderr_behavior = .Pipe;
    try child_process.spawn();
    _ = try child_process.stdin.?.write(bytes);
    child_process.stdin.?.close();
    _ = try child_process.wait();
    const errbuf: []u8 = try allocator.alloc(u8, 1024);
    var stderr_buf = std.array_list.Aligned(u8, null).initBuffer(errbuf);
    const outbuf: []u8 = try allocator.alloc(u8, 1024);
    var stdout_buf = std.array_list.Aligned(u8, null).initBuffer(outbuf);
    try child_process.collectOutput(allocator, &stdout_buf, &stderr_buf, 1024);
    std.debug.print("{s}", .{stdout_buf.items});
}

fn storeImage(allocator: Allocator, image_data: ImageData) !void {
    const subpath = try std.fs.path.join(
      allocator,
      &.{
        config.default_config.output_dir,
        image_data.foldername,
      },
    );
    try fs.cwd().makePath(subpath);

    var temp_buffer: [1024]u8 = undefined;
    const filename = try std.fmt.bufPrintZ(
        &temp_buffer,
        "{s}_{d:0>4}.{s}",
        .{ image_data.filename, image_data.frame, image_data.ext },
    );
    const filepath = try std.fs.path.join(
      allocator,
      &.{subpath, filename},
    );
    std.debug.print("{s}\n", .{filename});

    switch (image_data.data_format) {
        .DATA_URL => {
            const image_file = try fs.cwd().createFile(filepath, .{});
            defer image_file.close();
            const schema = "data:image/png;base64,";
            const data_str = image_data.data[schema.len..];
            const decoded_length = try b64_decoder.calcSizeForSlice(data_str);
            const data_decoded: []u8 = try allocator.alloc(u8, decoded_length);
            defer allocator.free(data_decoded);
            try b64_decoder.decode(data_decoded, data_str);
            try image_file.writeAll(data_decoded);
        },
        .RAW => {
            const img = zstbi.Image{
                .width = @intCast(image_data.width),
                .height = @intCast(image_data.height),
                .num_components = 4,
                .data = image_data.data[0..],
                .bytes_per_row = @intCast(image_data.width),
                .bytes_per_component = 1,
                .is_hdr = false,
            };
            zstbi.Image.writeToFile(img, filepath[0..:0], .png) catch |err| {
                std.log.err("{any}", .{err});
            };
        },
    }
}

fn storeBuffers(allocator: Allocator, i: usize) !void {
    while (true) {
        if (image_data_buffers[i].items.len == 0) continue;
        if (image_data_buffers[i].pop()) |next| {
            try storeImage(allocator, next);
        }
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    zstbi.init(allocator);
    zstbi.setFlipVerticallyOnWrite(true);
    defer zstbi.deinit();

    storage_threads = std.array_list.Managed(std.Thread).init(allocator);
    for (0..max_threads) |i| {
        image_data_buffers[i] = std.array_list.Managed(ImageData).init(allocator);
        const t = try std.Thread.spawn(.{}, storeBuffers, .{ allocator, i });
        try storage_threads.append(t);
    }

    var output_buffer = std.array_list.Managed(u8).init(allocator);
    defer output_buffer.deinit();

    var buffer: [256]u8 = undefined;
    var writer = output_buffer.writer().adaptToNewApi(&buffer).new_interface;
    try ziggy.stringify(config.default_config, .{}, &writer);
    std.debug.print("Framerecorder running...\nhttp://{s}:{d}\nctrl+c to stop\n", .{
        config.default_config.host,
        config.default_config.port,
    });
    std.debug.print("Config:\n{s}\n", .{writer.buffered()});

    var server = try tk.Server.init(allocator, routes, .{ .listen = .{
        .hostname = config.default_config.host,
        .port = config.default_config.port,
    }, .request = .{
        .max_body_size = 100 * 1920 * 1920,
    } });
    try server.start();
}

const routes: []const tk.Route = &.{
    tk.cors(),
    .group("/api", &.{.router(api)}),
    .send(error.NotFound),
};

const api = struct {
    pub fn @"PUT /ffmpeg"(req: *tk.Request, _: std.mem.Allocator, image_data: ImageData) !u32 {
        _ = req;
        _ = image_data;
        // @TODO
        return 501;
    }

    pub fn @"POST /imageseq"(req: *tk.Request, _: std.mem.Allocator, payload: ImageData) !u32 {
        _ = req;
        std.debug.print(">>>{f}\n", .{payload});
        try image_data_buffers[@mod(payload.frame, max_threads)].append(payload);
        return 200;
    }
};
