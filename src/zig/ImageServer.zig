const std = @import("std");
const config = @import("Config.zig");
const zstbi = @import("zstbi");
const tk = @import("tokamak");
const ImageData = @import("ImageData.zig");
const Allocator = std.mem.Allocator;

const b64 = std.base64;
const b64_decoder = b64.standard.Decoder;
const l = std.log.scoped(.framerecorder);

pub const ImageServer = struct {
    server: tk.Server,
    config: config.FramerecorderConfig,
};

pub fn storeImage(
    allocator: Allocator,
    io: std.Io,
    sequence: []const u8,
    frame: u32,
    image_data: ImageData,
) !void {
    const sub_path = try std.fs.path.join(
        allocator,
        &.{
            config.default.output_dir,
            sequence,
        },
    );
    defer allocator.free(sub_path);

    l.info("{s}\n", .{sub_path});
    try std.Io.Dir.cwd().createDirPath(
        io,
        sub_path,
    );

    var temp_buffer: [1024]u8 = undefined;
    const filename = try std.fmt.bufPrint(
        &temp_buffer,
        "{s}_{d:0>4}.{s}",
        .{ sequence, frame, image_data.ext },
    );
    defer allocator.free(filename);

    const filepath = try std.fs.path.joinZ(
        allocator,
        &.{ sub_path, filename },
    );
    defer allocator.free(filepath);
    l.debug(">>> {s}\n", .{filename});

    switch (image_data.img_format) {
        .DATA_URL => {
            const image_file = try std.Io.Dir.cwd().createFile(io, filepath, .{});
            errdefer image_file.close(io);
            const schema = "data:image/png;base64,";
            const data_str = image_data.data[schema.len..];
            const decoded_length = try b64_decoder.calcSizeForSlice(data_str);
            const data_decoded: []u8 = try allocator.alloc(u8, decoded_length);
            defer allocator.free(data_decoded);
            try b64_decoder.decode(data_decoded, data_str);
            try image_file.writePositionalAll(io, data_decoded, 0);
        },
        .RAW => {
            var image = zstbi.Image{
                .width = @intCast(image_data.width),
                .height = @intCast(image_data.height),
                .num_components = 4,
                .data = image_data.data[0..],
                .bytes_per_row = @intCast(image_data.width),
                .bytes_per_component = 1,
                .is_hdr = false,
            };
            defer image.deinit();
            zstbi.Image.writeToFile(image, filepath, .png) catch |err| {
                std.log.err("{any}", .{err});
            };
        },
    }
}

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
