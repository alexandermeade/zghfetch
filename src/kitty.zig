const mibu = @import("mibu");
const term = mibu.term;
const color = mibu.color;
const cursor = mibu.cursor;
const Io = std.Io;
const std = @import("std");
const base64 = std.base64.standard.Encoder;
const zigimg = @import("zigimg");

pub fn convert_jpeg_to_png(allocator: std.mem.Allocator, jpeg_bytes: []const u8) ![]u8 {
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

pub fn display_image(jpeg_data: []const u8, allocator: std.mem.Allocator, tty: std.fs.File) !void {
    const png_data = try convert_jpeg_to_png(allocator, jpeg_data);
    defer allocator.free(png_data);

    const encoded_len = base64.calcSize(png_data.len);
    const encrypted = try allocator.alloc(u8, encoded_len);
    defer allocator.free(encrypted);
    _ = base64.encode(encrypted, png_data);

    //Kitty protocal requires writer to ouptput to tty


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
pub fn display_png(png_data: []const u8, allocator: std.mem.Allocator, writer: *std.io.Writer) !void {
    const encoded_len = base64.calcSize(png_data.len);
    const encoded = try allocator.alloc(u8, encoded_len);
    defer allocator.free(encoded);
    _ = base64.encode(encoded, png_data);

    const payload_size = 4096;
    var start_index: usize = 0;
    var first_chunk = true;

    while (start_index < encoded_len) {
        var end_index = start_index + payload_size;
        const eof = end_index >= encoded_len;
        if (eof) end_index = encoded_len;
        const eof_flag: u8 = if (eof) '0' else '1';

        if (first_chunk) {
            try writer.print("\x1b_Ga=T,f=100,q=0,m={c};", .{eof_flag});
            first_chunk = false;
        } else {
            try writer.print("\x1b_Gm={c};", .{eof_flag});
        }

        try writer.writeAll(encoded[start_index..end_index]);
        try writer.writeAll("\x1b\\");
        try writer.flush();

        start_index += payload_size;
    }
    try writer.writeAll("\n");
    try writer.flush();
}



pub fn print_bottom_abs(writer: *std.io.Writer, comptime fmt: []const u8, args: anytype, pos: mibu.cursor.Position, x: usize, y: usize) !void {
    try mibu.cursor.goTo(writer, x, y);
    try writer.print(fmt, args);
    try mibu.cursor.goTo(writer, pos.col, pos.row);

    try writer.flush();
}




pub fn print_bottom_up(writer: *std.io.Writer, comptime fmt: []const u8, args: anytype, x: u64, y: u64) !void {
    try mibu.cursor.goUp(writer, y);
    try mibu.cursor.goRight(writer, x);
    try writer.print(fmt, args);
    try mibu.cursor.goDown(writer, y);
    try mibu.cursor.goLeft(writer, x);
    try writer.flush();
}
