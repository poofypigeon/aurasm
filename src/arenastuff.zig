const std = @import("std");

pub fn opt(c: u8) ?u8 {
    if (c == 'x') return c;
    return null;
}

pub fn main() !void {
    std.debug.print("{}\n", .{if (opt('y') == 'x') true else false});
}
