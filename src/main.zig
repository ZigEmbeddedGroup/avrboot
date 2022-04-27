const std = @import("std");
const testing = std.testing;

const serial = @import("serial.zig");
pub const stk = @import("stk500/stk.zig");

fn reset(port: std.fs.File) !void {
    // Fun fact: avrdude does
    // RTS/DTR = 0
    // ...
    // RTS/DTR = 1
    // ...
    // but this didn't work on my machine (which was usb-to-serial; might have to do with the behavior?)
    // so I flipped the pattern and it worked!

    try serial.changeControlPins(port, .{ .rts = true, .dtr = true });
    std.time.sleep(250 * std.time.ns_per_ms);

    try serial.changeControlPins(port, .{ .rts = false, .dtr = false });
    std.time.sleep(50 * std.time.ns_per_ms);
}

pub fn main() !void {
    var it = try serial.list();
    while (try it.next()) |port| {
        std.debug.print("{s} (file: {s}, driver: {s})\n", .{ port.display_name, port.file_name, port.driver });
    }

    var cfg = serial.SerialConfig{
        .handshake = .none,
        .baud_rate = 115200,
        .parity = .none,
        .word_size = 8,
        .stop_bits = .one,
    };

    var port = try std.fs.cwd().openFile(
        "\\\\.\\COM3", // if any, these will likely exist on a machine
        .{ .mode = .read_write },
    );
    defer port.close();

    try serial.configureSerialPort(port, cfg);

    var reader = port.reader();
    var writer = port.writer();

    try reset(port);
    try serial.flushSerialPort(port, true, true);

    var client = stk.stkClient(reader, writer);

    var attempt: usize = 0;
    while (attempt < 32) : (attempt += 1) {
        std.log.info("Sync attempt {d}...", .{attempt});

        if (attempt > 0) {
            try reset(port);
            try serial.flushSerialPort(port, true, true);
        }

        client.getSync() catch continue;
        std.log.info("In sync!", .{});
        break;
    }

    std.debug.assert(std.mem.eql(u8, &(try client.readSignatureBytes()), &[_]u8{ 0x1e, 0x95, 0x0f }));
    // try client.setDevice(std.mem.zeroes(stk.ProgrammingParameters));
    try client.setDevice(.{
        .device_code = 0x86,
        .revision = 0,
        .prog_type = .both,
        .parm_mode = .pseudo, // ?
        .polling = false, // ?
        .self_timed = false, // ?
        .lock_bytes = 1, // ?
        .fuse_bytes = 1,
        .flash_poll_val_1 = 0x53,
        .flash_poll_val_2 = 0x53,
        .eeprom_poll_val_1 = 0xff,
        .eeprom_poll_val_2 = 0xff,
        .page_size = 128,
        .eeprom_size = 1024,
        .flash_size = 32768,
    });
    try client.enterProgrammingMode();

    var hex_file = try std.fs.cwd().openFile("test-blinky-chips.atmega328p.bin", .{});
    defer hex_file.close();

    var address: u16 = 0;

    var size = (try hex_file.stat()).size;
    while (address < size) {
        try client.loadAddress(address);

        var buf: [128]u8 = undefined;
        var bytes_written = try hex_file.reader().read(&buf);

        std.log.info("Writing {d} at {d} (program size: {d})", .{ bytes_written, address, size });
        try client.programPagePreData(@intCast(u16, bytes_written));
        try port.writer().writeAll(buf[0..bytes_written]);
        try client.programPagePostData();

        address += @intCast(u16, bytes_written);
        std.time.sleep(4 * std.time.ns_per_ms);
    }

    try client.leaveProgrammingMode();
}

test {
    testing.refAllDecls(@This());
}
