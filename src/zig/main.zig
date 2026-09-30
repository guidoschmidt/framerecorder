const std = @import("std");
const tk = @import("tokamak");
const zstbi = @import("zstbi");
// const ziggy = @import("ziggy");
const Config = @import("Config.zig");
const img = @import("ImageData.zig");
const api = @import("api.zig");
const zon = std.zon;

const Allocator = std.mem.Allocator;
const fs = std.fs;
const l = std.log.scoped(.framerecorder);

const routes: []const tk.Route = &.{
    tk.cors(),
    .get("/openapi.json", tk.swagger.json(.{
        .info = .{ .title = "framerecorder" },
    })),
    .get("/docs", tk.swagger.ui(.{
        .url = "openapi.json",
    })),
    .group("/api", &.{
        .router(api),
    }),
    .send(error.NotFound),
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    zstbi.init(init.io, allocator);
    zstbi.setFlipVerticallyOnWrite(true);
    defer zstbi.deinit();

    var config = Config.default;

    var writer = std.Io.Writer.Allocating.init(allocator);
    defer writer.deinit();
    try zon.stringify.serialize(config, .{}, &writer.writer);
    const written = writer.writer.buffered();

    if (std.Io.Dir.readFileAllocOptions(
        std.Io.Dir.cwd(),
        init.io,
        "config.zon",
        allocator,
        .unlimited,
        .@"8",
        0,
    )) |data| {
        var diagnostics = std.zon.parse.Diagnostics{};
        const parsed = try zon.parse.fromSliceAlloc(
            Config,
            allocator,
            data[0..],
            &diagnostics,
            .{ .free_on_error = true },
        );
        config = parsed;
    } else |_| {
        l.info("Config file not found. Creating default!", .{});
        if (std.Io.Dir.createFile(std.Io.Dir.cwd(), init.io, "config.zon", .{})) |config_file| {
            try config_file.writeStreamingAll(init.io, written);
        } else |create_err| {
            l.err("{}", .{create_err});
        }
    }

    l.debug("Config:\n{f}\n", .{config});
    std.debug.print("Framerecorder running\n→ http://{s}:{d}/docs\nctrl+c to stop\n", .{
        config.host,
        config.port,
    });

    var server = try tk.Server.init(
        init.io,
        init.gpa,
        routes,
        .{
            .listen = .{
                .hostname = config.host,
                .port = config.port,
            },
            .request = .{
                .max_body_size = config.max_body_size,
            },
        },
    );
    try server.start();
}
