pub const uno = .{
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
};
