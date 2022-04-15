//! STK500v2 impl

const std = @import("std");
const utils = @import("utils.zig");

/// ID of commands and their responses
pub const CommandId = enum(u8) {
    // General
    sign_on = 0x01,
    set_parameter = 0x02,
    get_parameter = 0x03,
    set_device_parameters = 0x04,
    osccal = 0x05,
    load_address = 0x06,
    firmware_upgrade = 0x07,

    // ISP
    enter_progmode_isp = 0x10,
    leave_progmode_isp = 0x11,
    chip_erase_isp = 0x12,
    program_flash_isp = 0x13,
    read_flash_isp = 0x14,
    program_eeprom_isp = 0x15,
    read_eeprom_isp = 0x16,
    program_fuse_isp = 0x17,
    read_fuse_isp = 0x18,
    program_lock_isp = 0x19,
    read_lock_isp = 0x1a,
    read_signature_isp = 0x1b,
    read_osccal_isp = 0x1c,
    spi_multi = 0x1d,
};

pub const CommandError = error{
    CommandTimedOut,
    PinSamplingTimedOut,
    SetParamMissing,

    CommandFailed,
    InvalidChecksum,
    CommandUnknown,
};

pub const Status = enum(u8) {
    // Success
    /// Command executed OK
    cmd_ok = 0x00,

    // Warnings
    /// Command timed out
    cmd_tout = 0x80,
    /// Sampling of the RDY/nBSY pin timed out
    rdy_bsy_tout = 0x81,
    /// The ‘Set Device Parameters’ have not been executed in advance of this command
    set_param_missing = 0x82,

    // Errors
    /// Command failed
    cmd_failed = 0xC0,
    /// Checksum error
    cksum_error = 0xC1,
    /// Unknown command
    cmd_unknown = 0xC9,
};

pub const Parameter = enum(u8) {
    const RWArray = std.enums.EnumArray(Parameter, struct { read: bool, write: bool });
    pub const RW: RWArray = RWArray.init(.{
        .build_number_low = .{ .read = true, .write = false },
        .build_number_high = .{ .read = true, .write = false },
        .hw_ver = .{ .read = true, .write = false },
        .sw_major = .{ .read = true, .write = false },
        .sw_minor = .{ .read = true, .write = false },

        .vtarget = .{ .read = true, .write = true },
        .vadjust = .{ .read = true, .write = true },
        .osc_pscale = .{ .read = true, .write = true },
        .osc_cmatch = .{ .read = true, .write = true },
        .sck_duration = .{ .read = true, .write = true },

        .topcard_detect = .{ .read = true, .write = false },
        .status = .{ .read = true, .write = false },
        .data = .{ .read = true, .write = false },
        .reset_polarity = .{ .read = false, .write = true },
        .controller_init = .{ .read = true, .write = false },
    });

    /// Firmware build number, high byte (internal)
    build_number_low = 0x80,
    /// Firmware build number, low byte (internal)
    build_number_high = 0x81,
    /// Hardware version
    hw_ver = 0x90,
    /// Firmware version number, major byte
    sw_major = 0x91,
    /// Firmware version number, minor byte
    sw_minor = 0x92,

    /// Target voltage
    vtarget = 0x94,
    /// Adjustable (AREF) voltage
    vadjust = 0x95,
    /// Oscillator timer prescaler value
    osc_pscale = 0x96,
    /// Oscillator timer compare match value
    osc_cmatch = 0x97,
    /// ISP SCK duration
    sck_duration = 0x98,

    /// Top card detect
    topcard_detect = 0x9A,
    /// Returns status register
    status = 0x9C,
    /// DATA pins values used in HVPP mode
    data = 0x9D,
    /// Active low or active high RESET handling
    reset_polarity = 0x9E,
    /// Controller initialization
    controller_init = 0x9F,
};

pub const SetParameterCommand = struct {
    parameter: Parameter,
    value: u8,

    pub fn decode(reader: anytype) !SetParameterCommand {
        var spc: SetParameterCommand = undefined;
        spc.parameter = try utils.decodeAny(Parameter, reader);
        spc.value = try reader.readByte();
        return if (!Parameter.RW.get(spc.parameter).write)
            error.Invalid
        else
            spc;
    }
};
pub const GetParameterCommand = struct {
    parameter: Parameter,

    pub fn decode(reader: anytype) !GetParameterCommand {
        var gpc: GetParameterCommand = undefined;
        gpc.parameter = try utils.decodeAny(Parameter, reader);
        return if (!Parameter.RW.get(gpc.parameter).read)
            error.Invalid
        else
            gpc;
    }
};
pub const LoadAddressCommand = struct { address: u16 };
pub const FirmwareUpgradeCommand = struct { id: [9:0]u8 = "fwupgrade".* };

/// The poll value parameter indicates after which of the transmitted bytes on the SPI
/// interface to store the return byte, as the SPI interface is implemented as a ring
/// buffer (one byte out, one byte in)
pub const PollValue = enum(u8) {
    avr = 0x53,
    at89xx = 0x69,
};

pub const PollIndex = enum(u8) {
    no_polling = 0,
    avr = 3,
    at89xx = 4,
};

pub const EnterProgmodeCommand = struct {
    /// Command time-out (in ms)
    timeout: u8,
    /// Delay (in ms) used for pin stabilization
    stab_delay: u8,
    /// Delay (in ms) in connection with the EnterProgMode command execution
    cmdexe_delay: u8,
    /// Number of synchronization loops
    synch_loops: u8,
    /// Delay (in ms) between each byte in the EnterProgMode command.
    byte_delay: u8,
    /// Poll value
    poll_value: PollValue,
    /// Start address
    poll_index: PollIndex,
    // "instruction bytes found in the SPI Serial Programming Instruction Set found in the device datasheet"
    // TODO: figure out what this means
    command: [4]u8,
};

pub const CommandBody = union(CommandId) {
    // General
    sign_on,
    set_parameter: SetParameterCommand,
    get_parameter: GetParameterCommand,
    set_device_parameters, // TODO: ???
    osccal, // TODO: Look into "application note AVR053"
    load_address: LoadAddressCommand,
    firmware_upgrade: FirmwareUpgradeCommand,

    // ISP
    // TODO: Figure these out
    enter_progmode_isp: EnterProgmodeCommand,
    leave_progmode_isp,
    chip_erase_isp,
    program_flash_isp,
    read_flash_isp,
    program_eeprom_isp,
    read_eeprom_isp,
    program_fuse_isp,
    read_fuse_isp,
    program_lock_isp,
    read_lock_isp,
    read_signature_isp,
    read_osccal_isp,
    spi_multi,

    pub fn decode(reader: anytype) !CommandBody {
        var id = try reader.readByte();
        inline for (std.meta.fields(CommandBody)) |field| {
            if (@enumToInt(@field(CommandId, field.name)) == id)
                return @unionInit(CommandBody, field.name, try utils.decodeAny(field.field_type, reader));
        }

        @panic("Invalid data!");
    }
};

pub const AnswerBody = union(CommandId) {
    // General
    sign_on,
    set_parameter,
    get_parameter,
    set_device_parameters,
    osccal,
    load_address,
    firmware_upgrade,

    // ISP
    enter_progmode_isp,
    leave_progmode_isp,
    chip_erase_isp,
    program_flash_isp,
    read_flash_isp,
    program_eeprom_isp,
    read_eeprom_isp,
    program_fuse_isp,
    read_fuse_isp,
    program_lock_isp,
    read_lock_isp,
    read_signature_isp,
    read_osccal_isp,
    spi_multi,

    pub fn decode(reader: anytype) !AnswerBody {
        var id = try reader.readByte();
        var status = @intToEnum(Status, try reader.readByte());

        switch (status) {
            .cmd_ok => {},
            .cmd_tout => return error.CommandTimedOut,
            .rdy_bsy_tout => return error.PinSamplingTimedOut,
            .set_param_missing => return error.SetParamMissing,
            .cmd_failed => return error.CommandFailed,
            .cksum_error => return error.InvalidChecksum,
            .cmd_unknown => return error.CommandUnknown,
        }

        inline for (std.meta.fields(AnswerBody)) |field| {
            if (@enumToInt(@field(CommandId, field.name)) == id)
                return @unionInit(AnswerBody, field.name, try utils.decodeAny(field.field_type, reader));
        }

        @panic("Invalid data!");
    }
};

pub const MessageKind = enum { command, answer };
pub const MessageBody = union(MessageKind) {
    command: CommandBody,
    answer: AnswerBody,

    pub fn decode(reader: anytype, kind: MessageKind) !MessageBody {
        return switch (kind) {
            .command => MessageBody{ .command = try CommandBody.decode(reader) },
            .answer => MessageBody{ .answer = try AnswerBody.decode(reader) },
        };
    }
};

pub const Message = struct {
    /// NOTE: Wraps on overflow
    sequence_number: u8,
    body: MessageBody,

    pub fn decode(reader: anytype, kind: MessageKind) !Message {
        std.debug.assert((try reader.readByte()) == 0x1b);

        var sequence_number = try reader.readByte();
        var message_size = try reader.readIntBig(u16);

        std.debug.assert((try reader.readByte()) == 0x0e);

        var limited = std.io.limitedReader(reader, message_size);
        var message = Message{
            .sequence_number = sequence_number,
            .body = try MessageBody.decode(limited.reader(), kind),
        };

        var checksum = try reader.readByte();
        // TODO: Verify
        _ = checksum;

        return message;
    }

    // pub fn encode(self: Message, writer: anytype) !void {
    //     var counting = std.io.countingWriter(std.io.null_writer);

    //     var message_size = @intCast(u16, counting.bytes_written);
    // }
};

test "Simple" {
    var buf = [_]u8{ 0x02, 0x98, 0x01 };
    var fbs = std.io.fixedBufferStream(&buf);
    _ = try CommandBody.decode(fbs.reader());
}
