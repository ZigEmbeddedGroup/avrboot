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

pub const ResponseStatus = enum(u8) {
    stk_ok = 0x10,
    stk_failed = 0x11,
    stk_unknown = 0x12,
    stk_nodevice = 0x13,
    stk_insync = 0x14,
    stk_nosync = 0x15,

    adc_channel_error = 0x16,
    adc_measure_ok = 0x17,
    pwm_channel_error = 0x18,
    pwm_adjust_ok = 0x19,
};
