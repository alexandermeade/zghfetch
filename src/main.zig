const std = @import("std");
const curl = @import("curl");
const gituser = @import("gituser.zig");
const builtin = @import("builtin");

const mibu = @import("mibu");
const term = mibu.term;
const color = mibu.color;
const cursor = mibu.cursor;
const Io = std.Io;
const kitty = @import("kitty.zig");

pub fn setup_term(stdout: *std.Io.Writer) !void {
    // we have to make sure that exitAlternateScreen
    // and cursor.show are flushed when the program exits.
    defer stdout.*.flush() catch {};

    if (builtin.os.tag == .windows) {
        try mibu.enableWindowsVTS(stdout);
    }

    try term.enterAlternateScreen(stdout);
    defer term.exitAlternateScreen(stdout) catch {};

    try cursor.hide(stdout);
    defer cursor.show(stdout) catch {};
}


pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer if (gpa.deinit() != .ok) @panic("leak");

    const allocator = gpa.allocator();  
    const ca_bundle = try curl.allocCABundle(allocator);
    defer ca_bundle.deinit();
    
    const URL:[:0]const u8 = "https://api.github.com/users/alexandermeade";

    const easy = try curl.Easy.init(.{
        .ca_bundle = ca_bundle,
    });

    defer easy.deinit(); 
    
    const user = try gituser.GitHubUser.get_profile(URL, easy, allocator); 
    defer user.deinit();

    //try user.save_profile(easy, allocator);

    var stdout_buffer: [65536]u8 = undefined;
    
    var stdout_file = std.fs.File.stdout();

    var stdout_writer = stdout_file.writer(&stdout_buffer);

    const stdout = &stdout_writer.interface;
    //try setup_term(stdout);

    //ktry cursor.goTo(stdout, 1, 1);
    //try mibu.style.italic(stdout, true);
    //try stdout.print("This is being shown in the alternate screen...", .{});
    //try stdout.flush();
    const a: []const u8 = try user.fetch_profile(easy, allocator); 
    defer allocator.free(a);
    try kitty.displayImage(a, stdout, allocator);
}

