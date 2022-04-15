const std = @import("std");
const testing = std.testing;

pub const stk500v2 = @import("stk500v2/stk.zig");

test {
    testing.refAllDecls(@This());
}
