const std = @import("std");

const lineParsing = @import("encode.zig");
const globals = @import("globals.zig");

test {
    try lineParsing.processLine("nop");
}
