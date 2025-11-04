const std = @import("std");
const tk = @import("tokamak");
const zstbi = @import("zstbi");
const ziggy = @import("ziggy");
const config = @import("Config.zig");

const Allocator = std.mem.Allocator;
const fs = std.fs;
const cwd = fs.cwd();
const b64 = std.base64;
const b64_decoder = b64.standard.Decoder;

const l = std.log.scoped(.framerecorder);

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
    var temp_buffer: [1024]u8 = undefined;
    const subpath = try std.fmt.bufPrint(
        &temp_buffer,
        "./imgdata/{s}",
        .{image_data.foldername},
    );
    try cwd.makePath(subpath);

    var temp_buffer_2: [1024]u8 = undefined;
    const filename = try std.fmt.bufPrintZ(
        &temp_buffer_2,
        "{s}/{s}_{d:0>4}.{s}",
        .{ subpath, image_data.filename, image_data.frame, image_data.ext },
    );
    std.debug.print("{s}\n", .{filename});

    switch (image_data.data_format) {
        .DATA_URL => {
            const image_file = try fs.cwd().createFile(filename, .{});
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
            zstbi.Image.writeToFile(img, filename, .png) catch |err| {
                std.log.err("{any}", .{err});
            };
        },
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    zstbi.init(allocator);
    zstbi.setFlipVerticallyOnWrite(true);
    defer zstbi.deinit();

    var json_writer: std.Io.Writer.Allocating = .init(allocator);
    try ziggy.stringify(config.default_config, .{}, &json_writer.writer);
    std.debug.print("Framerecorder running\n→ http://{s}:{d}\nctrl+c to stop\n", .{
        config.default_config.host,
        config.default_config.port,
    });
    std.debug.print("Config:\n{s}\n", .{json_writer.written()});

    var server = try tk.Server.init(allocator, routes, .{ .listen = .{
        .hostname = config.default_config.host,
        .port = config.default_config.port,
    }, .request = .{
        .max_body_size = 256 + (1920 * 1920 * 4),
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

    pub fn @"POST /imageseq"(req: *tk.Request, allocator: std.mem.Allocator, payload: ImageData) !u32 {
        _ = req;
        std.debug.print(">>>{f}\n", .{payload});
        try storeImage(allocator, payload);
        return 200;
    }
};
