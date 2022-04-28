const std = @import("std");
const testing = std.testing;

const serial = @import("serial.zig");
pub const stk = @import("stk500/stk.zig");
pub const boards = @import("boards.zig");

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
    const allocator = std.heap.page_allocator;

    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        std.debug.print("avrboot [port] [.bin file]", .{});
        return;
    }

    var port_name = args[1];
    var file_name = args[2];

    var cfg = serial.SerialConfig{
        .handshake = .none,
        .baud_rate = 115200,
        .parity = .none,
        .word_size = 8,
        .stop_bits = .one,
    };

    var port = std.fs.cwd().openFile(
        port_name, // if any, these will likely exist on a machine "\\\\.\\COM3"
        .{ .mode = .read_write },
    ) catch {
        std.log.err("Could not open port!", .{});
        return;
    };
    defer port.close();

    var bin_file = std.fs.cwd().openFile(file_name, .{}) catch {
        std.log.err("Could not open bin file!", .{});
        return;
    };
    defer bin_file.close();

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
    try client.setDevice(boards.uno);
    try client.enterProgrammingMode();

    var address: u16 = 0;

    var size = (try bin_file.stat()).size;
    while (address < size) {
        try client.loadAddress(address);

        var buf: [128]u8 = undefined;
        var bytes_written = try bin_file.reader().read(&buf);

        std.log.info("Writing {d} at {d} (program size: {d})", .{ bytes_written, address, size });
        try client.programPage(buf[0..bytes_written], .flash);

        address += @intCast(u16, bytes_written);
        std.time.sleep(4 * std.time.ns_per_ms);
    }

    std.log.info("Program uploaded!", .{});

    address = 0;
    try bin_file.seekTo(0);
    while (address < size) {
        try client.loadAddress(address);

        var actual_buf: [128]u8 = undefined;
        var expected_buf: [128]u8 = undefined;

        var expected_bytes_written = try bin_file.reader().read(&expected_buf);
        _ = try client.readPage(&actual_buf, .flash);

        std.log.info("Verifying {d} at {d} (program size: {d})", .{ expected_bytes_written, address >> 1, size });

        if (!std.mem.eql(u8, actual_buf[0..expected_bytes_written], expected_buf[0..expected_bytes_written])) @panic("Upload error!");

        address += @intCast(u16, expected_bytes_written);
        std.time.sleep(4 * std.time.ns_per_ms);
    }

    std.log.info("Program verified!", .{});

    try client.leaveProgrammingMode();
}

test {
    testing.refAllDecls(@This());
}
