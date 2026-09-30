const std = @import("std");

pub const ImageDataFormat = enum(u3) {
    RAW = 0,
    DATA_URL = 1,
};

pub const ImageData = @This();

width: i32,
height: i32,
ext: []const u8,
img_format: ImageDataFormat = .RAW,
data: []u8,

pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
    var stringifier = std.json.Stringify{
        .writer = writer,
        .options = .{
            .whitespace = .indent_2,
        },
    };
    try stringifier.write(self);
}
