const std = @import("std");

pub const FramerecorderConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 8000,
};

pub const default_config = FramerecorderConfig{};
