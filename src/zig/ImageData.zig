const std = @import("std");

pub const ImageDataFormat = enum(u3) {
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
