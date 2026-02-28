const mibu = @import("mibu");
const term = mibu.term;
const color = mibu.color;
const cursor = mibu.cursor;
const Io = std.Io;
const std = @import("std");
const base64 = std.base64.standard.Encoder;
const zigimg = @import("zigimg");

pub fn convertJpegToPngMemory(allocator: std.mem.Allocator, jpeg_bytes: []const u8) ![]u8 {
    var image = try zigimg.Image.fromMemory(allocator, jpeg_bytes);
    defer image.deinit(allocator);

    const buffer = try allocator.alloc(u8, image.width * image.height * 4);
    defer allocator.free(buffer);
    const result = try image.writeToMemory(allocator, buffer, .{ .png = .{} });

    var file = try std.fs.cwd().createFile("test.png", .{});
    defer file.close();

    try file.writeAll(result);

    return try allocator.dupe(u8, result);
}

pub fn displayImage(jpeg_data: []const u8, allocator: std.mem.Allocator) !void {
    const png_data = try convertJpegToPngMemory(allocator, jpeg_data);
    defer allocator.free(png_data);

    const encoded_len = base64.calcSize(png_data.len);
    const encrypted = try allocator.alloc(u8, encoded_len);
    defer allocator.free(encrypted);
    _ = base64.encode(encrypted, png_data);

    //Kitty protocal requires writer to ouptput to tty
    const tty = try std.fs.openFileAbsolute("/dev/tty", .{ .mode = .write_only });
    defer tty.close();

    const payload_size = 4096;
    var start_index: usize = 0;
    var first_chunk = true;

    while (start_index < encoded_len) {
        var end_index = start_index + payload_size;
        const eof = end_index >= encoded_len;
        if (eof) end_index = encoded_len;

        const eof_flag = if (eof) "0" else "1";

        if (first_chunk) {
            const header = try std.fmt.allocPrint(allocator, "\x1b_Ga=T,f=100,q=0,m={s};", .{eof_flag});
            defer allocator.free(header);
            try tty.writeAll(header);
            first_chunk = false;
        } else {
            const header = try std.fmt.allocPrint(allocator, "\x1b_Gm={s};", .{eof_flag});
            defer allocator.free(header);
            try tty.writeAll(header);
        }

        try tty.writeAll(encrypted[start_index..end_index]);
        try tty.writeAll("\x1b\\");
        start_index += payload_size;
    }

    try tty.writeAll("\n");
}
