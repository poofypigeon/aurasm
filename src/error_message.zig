const std = @import("std");

const stderr = std.io.getStdErr();

const globals = @import("globals.zig");

const Tokenizer = @import("tokenizer.zig").Tokenizer;

// Error message is set and then error.ParseError is explicitly returned by encoder function
// Top level recieves and prints error message using context from tokenizer

const esc = "\x1B";
const csi = esc ++ "[";
const red = csi ++ "31m";
const green = csi ++ "32m";
const reset = csi ++ "0m";

const ParseErrorEnum = error{ParseError};

pub const ParseError = struct {
    text: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) ParseError {
        return ParseError{ .text = std.ArrayList(u8).init(allocator) };
    }

    pub inline fn msg(
        errMsg: *ParseError,
        comptime fmt: []const u8,
        args: anytype,
    ) !void {
        try errMsg.text.writer().print(fmt, args);
    }
};

/// Output an error message to stderr.
/// The error message includes a premable including the file path, row and
/// column where the most recently scanned token is located.
pub fn printError(comptime fmt: []const u8, args: anytype) !void {
    var buffer = std.io.bufferedWriter(stderr.writer());
    var writer = buffer.writer();

    // Error preamble
    try writer.print(
        "{s}:{d}:{d}: " ++ red ++ "error: " ++ reset,
        .{
            globals.path.items,
            globals.lineNumber + 1,
            globals.columnNumber + 1,
        },
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
