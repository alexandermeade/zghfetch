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
    const result = try image.writeToMemory(allocator, buffer, .{.png = .{}});

    var file = try std.fs.cwd().createFile("test.png", .{});
    defer file.close();

    try file.writeAll(result);

    return try allocator.dupe(u8, result);
}

pub fn displayImage(jpeg_data: []const u8, writer: *std.Io.Writer, allocator: std.mem.Allocator) !void {

    const png_data = try convertJpegToPngMemory(allocator, jpeg_data);
    defer allocator.free(png_data);

    const encoded_len = base64.calcSize(png_data.len);
    const encrypted = try allocator.alloc(u8, encoded_len);
    defer allocator.free(encrypted);
    std.debug.print("png_data.len={}, encrypted.len={}\n", .{png_data.len, encrypted.len});
    _ = base64.encode(encrypted, png_data);
    const header: []const u8 = "\x1b_Ga=T,f=100,m=0,q=1;";
    _ = try writer.write(header);
    _ = try writer.write(encrypted);
    _ = try writer.write("\x1b\\");
    try writer.writeAll("\n");
    try writer.flush();
}
