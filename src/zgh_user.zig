const std = @import("std");
const kitty = @import("kitty.zig");
const gituser = @import("gituser.zig");
const curl = @import("curl");
const mibu = @import("mibu"); 

pub const User = struct {
    name: []const u8,
    profile_url: [:0]const u8,
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


    pub fn display_user(self: @This(), easy: curl.Easy, allocator: std.mem.Allocator) !void {
        const tty = try std.fs.openFileAbsolute("/dev/tty", .{ .mode = .read_write });
        defer tty.close();
        // Wrap tty with a Mibu terminal writer
        const png_data = try self.profile_from_user(allocator);
        defer allocator.free(png_data);

        // Display the PNG

        var buf: [4096]u8 = undefined;
        var reader = tty.reader(&buf);
        var writer = tty.writer(&.{});
        var raw = try mibu.term.enableRawMode(tty.handle);
        
        try mibu.term.enterAlternateScreen(&writer.interface);

        try mibu.cursor.goRight(&writer.interface, 2);
        try (&writer.interface).flush();    

        try mibu.cursor.goDown(&writer.interface, 1);
        try (&writer.interface).flush();    
        try kitty.display_png(png_data, allocator, &writer.interface);
        try (&writer.interface).flush();    
        const size = try mibu.term.getSize(tty.handle);
        
        try writer.interface.flush();
        var pos = try mibu.cursor.getPosition(&reader.interface, &writer.interface);
        _ = &pos;
        _ = &reader;

        const user = try gituser.GitHubUser.get_profile(self.profile_url, easy, allocator);        
        defer user.deinit();
        const user_info = user.user_info.value;
        _ = &user_info;
        
        const colmn = pos.col + 30;
        var row = pos.row - 20;
        if (user_info.name) |name| {
            try kitty.print_bottom_abs(&writer.interface, "name: {s}", .{name}, pos, colmn, row);
        }
        row -= 1;
        if (user_info.bio) |bio| {
            try kitty.print_bottom_abs(&writer.interface, "bio: {s}", .{bio}, pos, colmn, row);
        }

        row -= 1;
        
        //try kitty.print_bottom_abs(&writer.interface, "followers: {}", .{user_info.followers}, pos, colmn, row);

        try mibu.cursor.goLeft(&writer.interface, size.width);
        try (&writer.interface).flush();    

        try raw.disableRawMode();
    }
};

