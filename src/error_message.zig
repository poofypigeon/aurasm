const std = @import("std");

const stderr = std.io.getStdErr();

const globals = @import("globals.zig");

const Tokenizer = @import("tokenizer.zig").Tokenizer;

const fmtExpected = "expected {s}, found '{s}'\n";

const esc = "\x1B";
const csi = esc ++ "[";
const red = csi ++ "31m";
const green = csi ++ "32m";
const reset = csi ++ "0m";

pub fn printError(comptime fmt: []const u8, args: anytype) !void {
    var buffer = std.io.bufferedWriter(stderr.writer());
    var writer = buffer.writer();

    // Error preamble
    try writer.print(
        "{s}:{d}:{d}: " ++ red ++ "error: " ++ reset,
        .{ globals.path.items, globals.lineNumber + 1, globals.columnNumber + 1 },
    );

    // Error message
    try writer.print(fmt, args);

    try buffer.flush();
}

pub fn displayTokenInLine(tokenizer: *Tokenizer) !void {
    var buffer = std.io.bufferedWriter(stderr.writer());
    var writer = buffer.writer();

    // Line that produced error
    try writer.print("{s}\n", .{tokenizer.line});

    // Identify and underline token that produced error
    var i: u32 = 0;
    try writer.print(green, .{});
    while (i < tokenizer.tokenStart) : (i += 1) {
        try writer.writeByte(' ');
    }
    try writer.writeByte('^');
    i += 1;
    try writer.print(reset ++ "\n", .{});

    try buffer.flush();
}

pub fn operatorListStr(comptime list: []const u8) []const u8 {
    return comptime blk: {
        var result: []const u8 = "";
        if (list.len == 1) break :blk "'" ++ list ++ "'";
        if (list.len == 2) break :blk "'" ++ .{list[0]} ++ "' or '" ++ .{list[1]} ++ "'";
        for (0.., list) |i, c| {
            if (i < list.len - 1) {
                result = result ++ "'" ++ .{c} ++ "', ";
            } else {
                result = result ++ "or '" ++ .{c} ++ "'";
            }
        }
        break :blk result;
    };
}
