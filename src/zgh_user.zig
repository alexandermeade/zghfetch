const std = @import("std");
const kitty = @import("kitty.zig");

pub const User = struct {
    name: []const u8,
    profile_path: []const u8,
    prev_fetch_time: []const u8,

    pub fn profile_from_user(self: @This(), allocator: std.mem.Allocator) ![]const u8 {
        const data = try std.fs.cwd().readFileAlloc(
            allocator,
            self.profile_path,
            std.math.maxInt(usize), 
        );

        return data;
    }

    pub fn display_user(self: @This(), allocator: std.mem.Allocator) !void {
        const png_data = try self.profile_from_user(allocator);    
        defer allocator.free(png_data);
        try kitty.display_png(png_data, allocator);
    }
};

