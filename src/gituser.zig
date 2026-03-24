const std = @import("std");
const curl = @import("curl");

pub const GitHubUserInfo = struct {
    login: ?[]const u8 = null,
    id: ?u64 = null,
    node_id: ?[]const u8 = null,
    avatar_url: ?[]const u8 = null,
    url: ?[]const u8 = null,
    html_url: ?[]const u8 = null,
    name: ?[]const u8 = null,
    company: ?[]const u8 = null,
    blog: ?[]const u8 = null,
    location: ?[]const u8 = null,
    email: ?[]const u8 = null,
    bio: ?[]const u8 = null,
    twitter_username: ?[]const u8 = null,
    public_repos: ?u32 = null,
    public_gists: ?u32 = null,
    followers: ?u32 = null,
    following: ?u32 = null,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
};

pub const GitHubUser = struct {
    user_info: std.json.Parsed(GitHubUserInfo),
    
    pub fn save_profile(self: @This(), easy: curl.Easy, allocator: std.mem.Allocator) !void {
        var img_writer = std.io.Writer.Allocating.init(allocator);
        defer img_writer.deinit();
        
        const url_z = try allocator.dupeZ(u8, self.user_info.value.avatar_url);
        defer allocator.free(url_z);
        
        _ = try easy.fetch(url_z, .{ .writer = @constCast(&img_writer.writer)});
        
        var img_items = img_writer.toArrayList();
        defer img_items.deinit(allocator);

        //std.debug.print("Status code: {d}\nImage size: {d} bytes\n", .{ img_resp.status_code, img_items.items.len});
            
        var file = try std.fs.cwd().createFile("profile.png", .{});
        defer file.close();

        try file.writeAll(img_items.items);
    }

    pub fn fetch_profile(self: @This(), easy: curl.Easy, allocator: std.mem.Allocator) ![] const u8 {
        //std.debug.print("\ngetting image\n", .{});
        var img_writer = std.io.Writer.Allocating.init(allocator);
        defer img_writer.deinit();
        
        const url_z = try allocator.dupeZ(u8, self.user_info.value.avatar_url);
        defer allocator.free(url_z);
        
        _ = try easy.fetch(url_z, .{ .writer = @constCast(&img_writer.writer)});
        
        var img_items = img_writer.toArrayList();
        defer img_items.deinit(allocator);

        //std.debug.print("Status code: {d}\nImage size: {d} bytes\n", .{ img_resp.status_code, img_items.items.len});
            
        var file = try std.fs.cwd().createFile("profile.png", .{});
        defer file.close();

        return img_items.toOwnedSlice(allocator);
    }


    pub fn get_profile(url: [:0]const u8, easy: curl.Easy, allocator: std.mem.Allocator) !@This() {
        var writer = std.io.Writer.Allocating.init(allocator);
        defer writer.deinit();
        _ = try easy.fetch(url, .{ .writer = @constCast(&writer.writer)});
        
        var items = writer.toArrayList();
        defer items.deinit(allocator);
        
        //std.debug.print("\nGET with fixed buffer as body\n", .{});
        //std.debug.print("Status code: {d}\nBody: {s}\n", .{ resp.status_code, items.items});
        
        const parsed_value = try std.json.parseFromSlice(GitHubUserInfo, allocator, items.items, .{ .ignore_unknown_fields = true, .allocate = .alloc_always});
        return .{.user_info = parsed_value}; 
    }

    pub fn deinit(self: @This()) void {
        self.user_info.deinit();
    }
};



