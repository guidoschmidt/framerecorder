const std = @import("std");
const tk = @import("tokamak");
const zstbi = @import("zstbi");

const Allocator = std.mem.Allocator;
const fs = std.fs;
const cwd = fs.cwd();
const b64 = std.base64;
const b64_decoder = b64.standard.Decoder;

const l = std.log.scoped(.zipper);

var temp_buffer: [256]u8 = undefined;
var image_data_buffer: std.ArrayList(ImageData) = undefined;
var storage_thread: std.Thread = undefined;

pub const ImageData = struct {
    frame: usize,
    width: i32,
    height: i32,
    data: []u8,
    foldername: []const u8,
    filename: []const u8,
    ext: []const u8,
};

fn storeImage(allocator: Allocator, image_data: ImageData) !void {
    const subpath = try std.fmt.bufPrintZ(&temp_buffer, "./imgdata/{s}", .{image_data.foldername});
    try cwd.makePath(subpath);
    const output_file = std.fmt.allocPrintZ(allocator, "{s}/{s}_{d:0>8}.{s}", .{
        subpath, image_data.filename, image_data.frame, image_data.ext,
    }) catch {
        @panic("Could not allocPrint!");
    };
    defer allocator.free(output_file);

    const img = zstbi.Image{
        .width = @intCast(image_data.width),
        .height = @intCast(image_data.height),
        .num_components = 4,
        .data = image_data.data[0..],
        .bytes_per_row = @intCast(image_data.width),
        .bytes_per_component = 1,
        .is_hdr = false,
    };
    zstbi.Image.writeToFile(img, output_file, .png) catch |err| {
        std.log.err("{any}", .{err});
    };

    std.debug.print("\n>>> {s}", .{output_file});

    // const schema = "data:image/png;base64,";
    // const data_str = image_data.imageData[schema.len..];
    // const decoded_length = try b64_decoder.calcSizeForSlice(data_str);
    // const data_decoded: []u8 = try allocator.alloc(u8, decoded_length);
    // defer allocator.free(data_decoded);
    // try b64_decoder.decode(data_decoded, data_str);
    // try out_file.writeAll(data_decoded);
}

fn storeBuffers(allocator: Allocator) !void {
    while (true) {
        if (image_data_buffer.items.len == 0) continue;
        if (image_data_buffer.pop()) |next| {
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

    image_data_buffer = std.ArrayList(ImageData).init(allocator);
    defer image_data_buffer.deinit();

    storage_thread = try std.Thread.spawn(.{}, storeBuffers, .{allocator});

    const port: u16 = 8000;
    std.debug.print("\nRunnig tokamak\n>>> http://127.0.0.1:{d}", .{port});

    var server = try tk.Server.init(allocator, routes, .{ .listen = .{
        .hostname = "127.0.0.1",
        .port = port,
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
    pub fn @"PUT /pixels"(req: *tk.Request, _: std.mem.Allocator, image_data: ImageData) !u32 {
        _ = req;
        try image_data_buffer.append(image_data);
        return 200;
    }

    pub fn @"PUT /data-url"(req: *tk.Request, allocator: std.mem.Allocator, image_data: ImageData) !u32 {
        _ = req;

        const schema = "data:image/png;base64,";
        const data_str = image_data.data[schema.len..];
        const decoded_length = b64_decoder.calcSizeForSlice(data_str) catch {
            l.err("Could not calculate size for slice", .{});
            return 500;
        };
        const data_decoded: []u8 = allocator.alloc(u8, decoded_length) catch {
            l.err("Could not decode data", .{});
            return 500;
        };
        b64_decoder.decode(data_decoded, data_str) catch return 500;

        const subpath = std.fmt.bufPrintZ(&temp_buffer, "./imgdata/{s}/", .{image_data.foldername}) catch {
            l.err("Could not format subpath {s}", .{image_data.foldername});
            return 500;
        };
        cwd.makePath(subpath) catch {
            l.err("Could not create subpath {s}", .{subpath});
            return 500;
        };

        const filename_with_ext = std.fmt.allocPrint(allocator, "{s}/{s}.{s}", .{ subpath, image_data.filename, image_data.ext }) catch return 500;
        defer allocator.free(filename_with_ext);

        const out_file = cwd.createFile(filename_with_ext, .{ .read = false }) catch return 500;
        defer out_file.close();
        out_file.writeAll(data_decoded) catch return 500;

        l.info("> {d}", .{image_data.frame});

        return 200;
    }
};
