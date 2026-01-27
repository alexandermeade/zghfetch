const std = @import("std");
const curl = @import("curl");
const URL = "https://api.github.com/users/alexandermeade";

const GitHubUser = struct {
    login: []const u8,
    id: u64,
    node_id: []const u8,
    avatar_url: [:0]const u8,
    url: []const u8,
    html_url: []const u8,
    name: ?[]const u8,
    company: ?[]const u8,
    blog: []const u8,
    location: ?[]const u8,
    email: ?[]const u8,
    bio: ?[]const u8,
    twitter_username: ?[]const u8,
    public_repos: u32,
    public_gists: u32,
    followers: u32,
    following: u32,
    created_at: []const u8,
    updated_at: []const u8,
};

pub fn save_img(bytes: []const u8) !void {
    var file = try std.fs.cwd().createFile("profile.png", .{});
    defer file.close();
    try file.writeAll(bytes);
}
pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer if (gpa.deinit() != .ok) @panic("leak");
    const allocator = gpa.allocator();
    const ca_bundle = try curl.allocCABundle(allocator);
    defer ca_bundle.deinit();
    
    const easy = try curl.Easy.init(.{
        .ca_bundle = ca_bundle,
    });
    defer easy.deinit(); 
    
    {
        std.debug.print("GET without body\n", .{});
        const resp = try easy.fetch(URL, .{});
        std.debug.print("Status code: {d}\n", .{resp.status_code});
    }
    
    // Move parsed_value outside the block so it stays alive
    var writer = std.io.Writer.Allocating.init(allocator);
    defer writer.deinit();
    const resp = try easy.fetch(URL, .{ .writer = @constCast(&writer.writer)});
    var items = writer.toArrayList();
    defer items.deinit(allocator);
    
    std.debug.print("\nGET with fixed buffer as body\n", .{});
    std.debug.print("Status code: {d}\nBody: {s}\n", .{ resp.status_code, items.items});
    
    const parsed_value = try std.json.parseFromSlice(GitHubUser, allocator, items.items, .{ .ignore_unknown_fields = true});
    defer parsed_value.deinit(); // Defer this to the end of main
    
    const user = parsed_value.value;
    
    // Now use user
    std.debug.print("\ngetting image\n", .{});
    var img_writer = std.io.Writer.Allocating.init(allocator);
    defer img_writer.deinit();
    
    const url_z = try allocator.dupeZ(u8, user.avatar_url);
    defer allocator.free(url_z);
    
    const img_resp = try easy.fetch(url_z, .{ .writer = @constCast(&img_writer.writer)});
    var img_items = img_writer.toArrayList();
    defer img_items.deinit(allocator);
    std.debug.print("Status code: {d}\nImage size: {d} bytes\n", .{ img_resp.status_code, img_items.items.len});
    
    try save_img(img_items.items);
    std.debug.print("Saved to profile.png\n", .{});
}
