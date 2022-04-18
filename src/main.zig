const std = @import("std");
const testing = std.testing;

const serial = @import("serial.zig");
pub const stk = @import("stk500v2/stk.zig");

pub fn touchSerialPortAt1200Bps(port: []const u8) !void {
    var cfg = serial.SerialConfig{
        .handshake = .none,
        .baud_rate = 115200,
        .parity = .none,
        .word_size = 8,
        .stop_bits = .one,
    };

    var port_file = try std.fs.cwd().openFile(
        port, // if any, these will likely exist on a machine
        .{ .mode = .read_write },
    );

    try serial.configureSerialPort(port_file, cfg);

    try serial.changeControlPins(port_file, .{ .rts = false, .dtr = false });
    std.time.sleep(250 * std.time.ns_per_ms);

    try serial.changeControlPins(port_file, .{ .rts = true, .dtr = true });
    std.time.sleep(50 * std.time.ns_per_ms);

    try serial.flushSerialPort(port_file, true, true);

    var reader = port_file.reader();
    // var writer = port_file.writer();

    // var init_msg = stk.Message{
    //     .sequence_number = 0,
    //     .body = .{ .command = .sign_on },
    // };

    // try init_msg.encode(writer);

    while (true) {
        var buf: [10]u8 = undefined;
        _ = try reader.readAll(&buf);
        std.log.err("{d}", .{buf});
    }

    port_file.close();
}

pub fn main() !void {
    var it = try serial.list();
    while (try it.next()) |port| {
        std.debug.print("{s} (file: {s}, driver: {s})\n", .{ port.display_name, port.file_name, port.driver });
    }
    try touchSerialPortAt1200Bps(if (@import("builtin").os.tag == .windows) "\\\\.\\COM3" else "/dev/ttyUSB0");
    // it = try serial.list();
    // while (try it.next()) |port| {
    //     std.debug.print("{s} (file: {s}, driver: {s})\n", .{ port.display_name, port.file_name, port.driver });
    // }

    // var reader = port.reader();
    // var writer = port.writer();

    // try serial.changeControlPins(port, .{ .dtr = false });

    // var init_msg = stk.Message{
    //     .sequence_number = 0,
    //     .body = .{ .command = .sign_on },
    // };

    // try init_msg.encode(writer);

    // while (true) {
    //     var buf: [10]u8 = undefined;
    //     _ = try port.reader().readAll(&buf);
    //     std.log.err("{d}", .{buf});
    // }

    // std.log.err("{s}", .{
    //     try stk.Message.decode(reader, .answer),
    // });
}

test {
    testing.refAllDecls(@This());
}
