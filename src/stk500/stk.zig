//! STK500v2 impl

const std = @import("std");
const utils = @import("../utils.zig");

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
