const std = @import("std");

const Config = @This();

output_dir: []const u8 = "imagedata",
host: []const u8 = "127.0.0.1",
port: u16 = 8000,
max_body_size: usize = 256 + (1920 * 1920 * 4),

pub fn format(self: Config, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    var stringifier = std.json.Stringify{
        .writer = writer,
        .options = .{
            .whitespace = .indent_2,
        },
    };
    try stringifier.write(self);
}

pub const default = Config{};
