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

pub fn displayImage(jpeg_data: []const u8, writer: *std.Io.Writer, allocator: std.mem.Allocator) !void {
    const png_data = try convertJpegToPngMemory(allocator, jpeg_data);
    defer allocator.free(png_data);

    const encoded_len = base64.calcSize(png_data.len);
    const encrypted = try allocator.alloc(u8, encoded_len);
    defer allocator.free(encrypted);
    const payload_size = 4096;

    //std.debug.print("png_data.len={}, encrypted.len={}\n", .{ png_data.len, encrypted.len });
    _ = base64.encode(encrypted, png_data);
    var start_index: usize = 0;
    var end_index: usize = 0;
    var eof = false;
    var first_chunk = true;

    while (!eof) {
        if (start_index >= encoded_len) {
            break;
        }

        end_index = start_index + payload_size;

        eof = start_index + payload_size >= encoded_len;

        if (end_index >= encoded_len) {
            end_index = encrypted.len;
        }

        const header_header = if (first_chunk) "\x1b_Ga=T,f=100,q=0,m=" else "\x1b_Gm=";
        const eof_flag = if (eof) "0" else "1";

        const header = try std.fmt.allocPrint(
            allocator,
            "{s}{s};",
            .{ header_header, eof_flag },
        );

        defer allocator.free(header);

        if (first_chunk) {
            first_chunk = !first_chunk;
        }

        _ = try writer.write(header);
        _ = try writer.write(encrypted[start_index..end_index]);
        _ = try writer.write("\x1b\\");
        start_index += payload_size;
    }

    try writer.writeAll("\n");

    try writer.flush();
}
