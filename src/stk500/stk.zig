//! STK500v2 impl

const std = @import("std");
const utils = @import("../utils.zig");

/// Indicates end of command
const EOP = ' ';

/// ID of commands and their responses
pub const CommandId = enum(u8) {
    get_sync = 0x30,
    get_sign_on = 0x31,

    set_parameter = 0x40,
    get_parameter = 0x41,
    set_device = 0x42,
    set_device_ext = 0x45,

    enter_progmode = 0x50,
    leave_progmode = 0x51,
    chip_erase = 0x52,
    check_autoinc = 0x53,
    load_address = 0x55,
    universal = 0x56,
    universal_multi = 0x57,

    prog_flash = 0x60,
    prog_data = 0x61,
    prog_fuse = 0x62,
    prog_lock = 0x63,
    prog_page = 0x64,
    prog_fuse_ext = 0x65,

    read_flash = 0x70,
    read_data = 0x71,
    read_fuse = 0x72,
    read_lock = 0x73,
    read_page = 0x74,
    read_sign = 0x75,
    read_osccal = 0x76,
    read_fuse_ext = 0x77,
    read_osccal_ext = 0x78,
};

pub const CommandError = error{
    Failed,
    Unknown,
    ADCChannel,
    PWMChannel,
};

pub const ResponseStatus = enum(u8) {
    ok = 0x10,
    failed = 0x11,
    unknown = 0x12,
    no_device = 0x13,
    in_sync = 0x14,
    no_sync = 0x15,

    adc_channel_error = 0x16,
    adc_measure_ok = 0x17,
    pwm_channel_error = 0x18,
    pwm_adjust_ok = 0x19,
};

pub const Parameter = enum(u8) {
    const RWArray = std.enums.EnumArray(Parameter, struct { read: bool, write: bool });
    pub const RW: RWArray = RWArray.init(.{
        .hw_ver = .{ .read = true, .write = false },
        .sw_major = .{ .read = true, .write = false },
        .sw_minor = .{ .read = true, .write = false },
        .leds = .{ .read = true, .write = true },
        .vtarget = .{ .read = true, .write = true },
        .vadjust = .{ .read = true, .write = true },
        .osc_pscale = .{ .read = true, .write = true },
        .osc_cmatch = .{ .read = true, .write = true },
        .reset_duration = .{ .read = true, .write = true },
        .sck_duration = .{ .read = true, .write = true },

        .bufsizel = .{ .read = true, .write = false },
        .bufsizeh = .{ .read = true, .write = false },
        .device = .{ .read = true, .write = false },
        .progmode = .{ .read = true, .write = false },
        .paramode = .{ .read = true, .write = false },
        .polling = .{ .read = true, .write = false },
        .selftimed = .{ .read = true, .write = false },
        .topcard_detect = .{ .read = true, .write = false },
    });

    hw_ver = 0x80,
    sw_major = 0x81,
    sw_minor = 0x82,
    leds = 0x83,
    vtarget = 0x84,
    vadjust = 0x85,
    osc_pscale = 0x86,
    osc_cmatch = 0x87,
    reset_duration = 0x88,
    sck_duration = 0x89,

    bufsizel = 0x90,
    bufsizeh = 0x91,
    device = 0x92,
    /// 'P' or 'S'
    progmode = 0x93,
    /// "TRUE" or "FALSE"
    paramode = 0x94,
    /// "TRUE" or "FALSE"
    polling = 0x95,
    /// "TRUE" or "FALSE"
    selftimed = 0x96,
    topcard_detect = 0x98,
};

pub const ProgType = enum(u8) {
    /// Both Parallel/High-voltage and Serial mode
    both = 0,
    /// Only Parallel/High-voltage
    only = 1,
};

pub const InterfaceType = enum(u8) {
    /// Pseudo parallel interface
    pseudo = 0,
    /// Full parallel interface
    full = 1,
};

pub const ProgrammingParameters = struct {
    /// Device code as defined in “devices.h”
    device_code: u8,
    /// Device revision. Currently not used. Should be set to 0.
    revision: u8,
    /// Defines which Program modes is supported
    prog_type: ProgType,
    /// Defines if the device has a full parallel interface or a
    /// pseudo parallel programming interface
    parm_mode: InterfaceType,
    /// Defines if polling may be used during SPI access
    polling: bool,
    /// Defines if programming instructions are self timed
    self_timed: bool,
    /// Number of Lock bytes. Currently not used. Should be set
    /// to actual number of Lock bytes for future compability.
    lock_bytes: u8,
    /// Number of Fuse bytes. Currently not used. Should be set
    /// to actual number of Fuse bytes for future caompability
    fuse_bytes: u8,
    /// FLASH polling value. See Data Sheet for the device.
    flash_poll_val_1: u8,
    /// FLASH polling value. Same as flash_poll_val_1
    flash_poll_val_2: u8,
    /// EEPROM polling value 1 (P1). See data sheet for the device.
    eeprom_poll_val_1: u8,
    /// EEPROM polling value 2 (P2). See data sheet for the device.
    eeprom_poll_val_2: u8,
    page_size: u16,
    eeprom_size: u16,
    flash_size: u32,
};

pub const MemType = enum(u8) {
    eeprom = 'E',
    flash = 'F',
};

pub fn STKClient(comptime ReaderType: type, comptime WriterType: type) type {
    return struct {
        reader: ReaderType,
        writer: WriterType,

        const Self = @This();

        pub const ReadWriteError = ReaderType.Error || WriterType.Error || error{ NoSync, EndOfStream };
        const CheckSyncError = ReaderType.Error || error{ NoSync, EndOfStream };

        fn checkSync(self: Self) CheckSyncError!void {
            return switch (@intToEnum(ResponseStatus, try self.reader.readByte())) {
                .in_sync => {},
                .no_sync => error.NoSync,
                else => @panic("Invalid sync response!"),
            };
        }

        pub const GetSyncError = ReadWriteError;
        pub fn getSync(self: Self) GetSyncError!void {
            try self.writer.writeAll(&[_]u8{ @enumToInt(CommandId.get_sync), EOP });

            try self.checkSync();

            return switch (@intToEnum(ResponseStatus, try self.reader.readByte())) {
                .ok => {},
                else => @panic("Invalid response!"),
            };
        }

        pub const GetParameterError = ReadWriteError || error{Failed};
        pub fn getParameter(self: Self, param: Parameter) GetParameterError!u8 {
            std.debug.assert(Parameter.RW.get(param).read);

            try self.writer.writeAll(&[_]u8{ @enumToInt(CommandId.get_parameter), @enumToInt(param), EOP });

            try self.checkSync();
            var data: [2]u8 = undefined;
            _ = try self.reader.readAll(&data);

            return switch (@intToEnum(ResponseStatus, data[1])) {
                .ok => data[0],
                .failed => error.Failed,
                else => @panic("Invalid response!"),
            };
        }

        pub const ReadSignatureBytesError = ReadWriteError;
        pub fn readSignatureBytes(self: Self) ReadSignatureBytesError![3]u8 {
            try self.writer.writeAll(&[_]u8{ @enumToInt(CommandId.read_sign), EOP });

            try self.checkSync();
            var data: [4]u8 = undefined;
            _ = try self.reader.readAll(&data);

            return switch (@intToEnum(ResponseStatus, data[3])) {
                .ok => data[0..3].*,
                else => @panic("Invalid response!"),
            };
        }

        pub const SetDeviceError = ReadWriteError;
        pub fn setDevice(self: Self, params: ProgrammingParameters) SetDeviceError!void {
            try self.writer.writeAll(&[_]u8{
                @enumToInt(CommandId.set_device),
                params.device_code,
                params.revision,
                @enumToInt(params.prog_type),
                @enumToInt(params.parm_mode),
                if (params.polling) 1 else 0,
                if (params.self_timed) 1 else 0,
                params.lock_bytes,
                params.fuse_bytes,
                params.flash_poll_val_1,
                params.flash_poll_val_2,
                params.eeprom_poll_val_1,
                params.eeprom_poll_val_1,
            });
            try self.writer.writeIntLittle(u16, params.page_size);
            try self.writer.writeIntLittle(u16, params.eeprom_size);
            try self.writer.writeIntLittle(u32, params.flash_size);
            try self.writer.writeByte(EOP);

            try self.checkSync();

            return switch (@intToEnum(ResponseStatus, try self.reader.readByte())) {
                .ok => {},
                else => @panic("Invalid response!"),
            };
        }

        pub const EnterProgrammingModeError = ReadWriteError || error{NoDevice};
        pub fn enterProgrammingMode(self: Self) EnterProgrammingModeError!void {
            try self.writer.writeAll(&[_]u8{ @enumToInt(CommandId.enter_progmode), EOP });

            try self.checkSync();

            return switch (@intToEnum(ResponseStatus, try self.reader.readByte())) {
                .ok => {},
                .no_device => error.NoDevice,
                else => @panic("Invalid response!"),
            };
        }

        pub const LeaveProgrammingModeError = ReadWriteError;
        pub fn leaveProgrammingMode(self: Self) LeaveProgrammingModeError!void {
            try self.writer.writeAll(&[_]u8{ @enumToInt(CommandId.leave_progmode), EOP });

            try self.checkSync();

            return switch (@intToEnum(ResponseStatus, try self.reader.readByte())) {
                .ok => {},
                else => @panic("Invalid response!"),
            };
        }

        pub const LoadAddressError = ReadWriteError;
        pub fn loadAddress(self: Self, address: u16) LoadAddressError!void {
            try self.writer.writeByte(@enumToInt(CommandId.load_address));
            // NOTE: Address must be `>> 1` for this to work for some strange reason; beware of this!!
            // TODO: Does this only apply in certain cases? If so, why??
            try self.writer.writeIntLittle(u16, address >> 1);
            try self.writer.writeByte(EOP);

            try self.checkSync();

            return switch (@intToEnum(ResponseStatus, try self.reader.readByte())) {
                .ok => {},
                else => @panic("Invalid response!"),
            };
        }

        pub const ProgramPageError = ReadWriteError;
        pub fn programPage(self: Self, buf: []const u8, mem_type: MemType) ProgramPageError!void {
            try self.writer.writeByte(@enumToInt(CommandId.prog_page));
            try self.writer.writeIntBig(u16, @intCast(u16, buf.len));
            try self.writer.writeByte(@enumToInt(mem_type));
            try self.writer.writeAll(buf);
            try self.writer.writeByte(EOP);

            try self.checkSync();

            return switch (@intToEnum(ResponseStatus, try self.reader.readByte())) {
                .ok => {},
                else => @panic("Invalid response!"),
            };
        }

        pub const ReadPageError = ReadWriteError;
        pub fn readPage(self: Self, buf: []u8, mem_type: MemType) ReadPageError!usize {
            try self.writer.writeByte(@enumToInt(CommandId.read_page));
            try self.writer.writeIntBig(u16, @intCast(u16, buf.len));
            try self.writer.writeAll(&[_]u8{ @enumToInt(mem_type), EOP });

            try self.checkSync();

            var bytes_read = try self.reader.readAll(buf);

            return switch (@intToEnum(ResponseStatus, try self.reader.readByte())) {
                .ok => bytes_read,
                else => @panic("Invalid response!"),
            };
        }
    };
}

pub fn stkClient(reader: anytype, writer: anytype) STKClient(@TypeOf(reader), @TypeOf(writer)) {
    return STKClient(@TypeOf(reader), @TypeOf(writer)){ .reader = reader, .writer = writer };
}
