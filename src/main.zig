const std = @import("std");
const testing = std.testing;

const serial = @import("serial.zig");
pub const stk = @import("stk500/stk.zig");

const CommTimeouts = extern struct {
    read_interval_timeout: std.os.windows.DWORD,
    read_total_timeout_multiplier: std.os.windows.DWORD,
    read_total_timeout_constant: std.os.windows.DWORD,
    write_total_timeout_multiplier: std.os.windows.DWORD,
    write_total_timeout_constant: std.os.windows.DWORD,
};

extern "kernel32" fn GetCommTimeouts(
    hFile: std.os.windows.HANDLE,
    lpCommTimeouts: *CommTimeouts,
) std.os.windows.BOOL;

extern "kernel32" fn SetCommTimeouts(
    hFile: std.os.windows.HANDLE,
    lpCommTimeouts: *CommTimeouts,
) std.os.windows.BOOL;

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

    var ct = std.mem.zeroes(CommTimeouts);
    if (GetCommTimeouts(port.handle, &ct) == 0)
        return error.WindowsError;

    ct.read_interval_timeout = 0;
    ct.read_total_timeout_multiplier = 100;
    ct.read_total_timeout_constant = 100;

    if (SetCommTimeouts(port.handle, &ct) == 0)
        return error.WindowsError;

    try serial.configureSerialPort(port, cfg);

    var reader = port.reader();
    var writer = port.writer();

    try reset(port);
    try serial.flushSerialPort(port, true, true);

    const buf = &[_]u8{ @enumToInt(stk.CommandId.get_sync), 0x20 };

    var attempt: usize = 0;
    while (attempt < 32) : (attempt += 1) {
        std.log.info("Sync attempt {d}...", .{attempt});

        if (attempt > 0) {
            try reset(port);
            try serial.flushSerialPort(port, true, true);
        }

        try serial.flushSerialPort(port, true, true);
        try writer.writeAll(buf);

        if ((reader.readByte() catch continue) == @enumToInt(stk.ResponseStatus.in_sync)) {
            std.log.info("In sync!", .{});
            break;
        } else {
            @panic("so this shouldnt happen...");
        }
    }

    // writer.writeAll(&[_]u8{});
}

test {
    testing.refAllDecls(@This());
}
