const std = @import("std");

pub fn ChecksumReader(comptime ReaderType: anytype) type {
    return struct {
        child_reader: ReaderType,
        checksum: u8 = 0,

        pub const Error = ReaderType.Error;
        pub const Reader = std.io.Reader(*@This(), Error, read);

        pub fn read(self: *@This(), buf: []u8) Error!usize {
            const amt = try self.child_reader.read(buf);
            for (buf) |byte| self.checksum = self.checksum ^ byte;
            return amt;
        }

        pub fn reader(self: *@This()) Reader {
            return .{ .context = self };
        }
    };
}

pub fn checksumReader(child_reader: anytype) ChecksumReader(@TypeOf(child_reader)) {
    return ChecksumReader(@TypeOf(child_reader)){ .child_reader = child_reader };
}

test "ChecksumReader" {
    var data = [_]u8{ 0x1b, 0x00, 0x00, 0x04, 0x0e, 0xff, 0xff, 0xff, 0xff, 0x11 };
    var base_reader = std.io.fixedBufferStream(&data).reader();
    var csum = checksumReader(base_reader);

    var data_before_csum: [data.len - 1]u8 = undefined;
    _ = try csum.reader().readAll(&data_before_csum);

    var actual = csum.checksum;
    var expected = try csum.reader().readByte();

    try std.testing.expectEqual(expected, actual);
}

pub fn ChecksumWriter(comptime WriterType: anytype) type {
    return struct {
        child_writer: WriterType,
        checksum: u8 = 0,

        pub const Error = WriterType.Error;
        pub const Writer = std.io.Writer(*Self, Error, write);

        const Self = @This();

        pub fn write(self: *Self, bytes: []const u8) Error!usize {
            const amt = try self.child_writer.write(bytes);
            for (bytes) |byte| self.checksum = self.checksum ^ byte;
            return amt;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }
    };
}

pub fn checksumWriter(child_writer: anytype) ChecksumWriter(@TypeOf(child_writer)) {
    return ChecksumWriter(@TypeOf(child_writer)){ .child_writer = child_writer };
}

test "ChecksumWriter" {
    var buf: [10]u8 = undefined;
    var base_writer = std.io.fixedBufferStream(&buf).writer();
    var csum = checksumWriter(base_writer);

    try csum.writer().writeAll(&[_]u8{ 0x1b, 0x00, 0x00, 0x04, 0x0e, 0xff, 0xff, 0xff, 0xff });
    try csum.writer().writeByte(csum.checksum);

    try std.testing.expectEqual([_]u8{ 0x1b, 0x00, 0x00, 0x04, 0x0e, 0xff, 0xff, 0xff, 0xff, 0x11 }, buf);
}

pub fn decodeAny(comptime T: type, reader: anytype) anyerror!T {
    const info = @typeInfo(T);

    return switch (info) {
        .Void => {},
        .Int => |int| switch (int.bits) {
            8 => try reader.readByte(),
            else => try reader.readIntBig(T),
        },
        .Struct, .Enum, .Union => if (@hasDecl(T, "decode")) try @field(T, "decode")(reader) else switch (info) {
            .Struct => {
                var data: T = undefined;
                inline for (std.meta.fields(T)) |field| {
                    @field(data, field.name) = try decodeAny(field.field_type, reader);
                }
                return data;
            },
            .Enum => |e| return @intToEnum(T, try decodeAny(e.tag_type, reader)),
            else => @panic("Cannot decode: " ++ @typeName(T)),
        },
        .Array => {
            var buf: T = undefined;
            _ = try reader.readAll(&buf);
            return buf;
        },
        else => @compileError("Cannot decode: " ++ @typeName(T)),
    };
}

pub fn encodeAny(writer: anytype, value: anytype) !void {
    const T = @TypeOf(value);
    const info = @typeInfo(T);

    return switch (info) {
        .Void => {},
        .Int => writer.writeIntBig(T, value),
        .Struct, .Enum, .Union => if (@hasDecl(T, "encode")) try @field(T, "encode")(writer, value) else switch (info) {
            .Struct => {
                inline for (std.meta.fields(T)) |field| {
                    try encodeAny(writer, @field(value, field.name));
                }
            },
            .Enum => encodeAny(writer, @enumToInt(value)),
            else => @panic("Cannot encode: " ++ @typeName(T)),
        },
        .Array => {
            _ = try writer.writeAll(&value);
        },
        else => @compileError("Cannot decode: " ++ @typeName(T)),
    };
}
