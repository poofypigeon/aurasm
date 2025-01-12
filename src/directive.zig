const std = @import("std");

const Tokenizer = @import("Tokenizer.zig");

const parsing = @import("parsing.zig");
const Diagnostic = parsing.Diagnostic;

pub const Directive = enum {
    data,
    text,
    bss,
    @"extern",
    @"export",
    @"align",
    word,
    half,
    byte,
    string,
    // macro, endm, // TODO
};

pub const stringMap = std.StaticStringMap(Directive).initComptime(.{
    .{ "data", .data },
    .{ "text", .text },
    .{ "bss", .bss },
    .{ "word", .word },
    .{ "half", .half },
    .{ "byte", .byte },
    .{ "string", .string },
    .{ "extern", .@"extern" },
    .{ "export", .@"export" },
    .{ "align", .@"align" },
});

pub fn parseBssDeclaration(line: *Tokenizer, diag: *Diagnostic) !struct { label: []const u8, size: u32 } {
    // Parse label
    const label = try parsing.parseSymbol(line, diag);
    // Parse .bss segment size
    const token = line.next() orelse {
        try diag.msg("expected .bss segment size\n", .{});
        return error.ParseError;
    };
    const segmentSize = parsing.parseInteger(token) catch |err| {
        switch (err) {
            error.Unexpected => try diag.msg("expected .bss segment size\n", .{}),
            error.ValueNotEncodable => try diag.msg("value is too large", .{}),
        }
        return err;
    };
    return .{ .label = label, .size = segmentSize };
}

pub fn parseAlignDirective(line: *Tokenizer, diag: *Diagnostic) !usize {
    // Parse alignment value
    const token = line.next() orelse {
        try diag.msg("expected alignment value\n", .{});
        return error.ParseError;
    };
    const alignment = parsing.parseInteger(token) catch |err| {
        switch (err) {
            error.Unexpected => try diag.msg("expected alignment value\n", .{}),
            error.ValueNotEncodable => try diag.msg("value is too large", .{}),
        }
        return err;
    };
    if (@popCount(alignment) != 1) {
        try diag.msg("alignment value must be a power of 2", .{});
        return error.ParseError;
    }
    return alignment;
}

const baseArrayCap = 128;

pub fn parseStaticData(
    comptime T: type,
    allocator: std.mem.Allocator,
    depth: u1,
    line: *Tokenizer,
    diag: *Diagnostic,
) error{ Overflow, ParseError, OutOfMemory }![]u8 {
    comptime switch (@typeInfo(T)) {
        .Int => |int| {
            if (int.signedness == .signed or (int.bits != 8 and int.bits != 16 and int.bits != 32)) {
                @compileError("T must be u8, u16, or u32");
            }
        },
        else => @compileError("T must be u8, u16, or u32"),
    };

    // Positive values must be less than this value to be representable in `numBytes`
    const posMax: u32 = comptime std.math.maxInt(T);
    // Negated values must be greater than this value to be representable in `numBytes`
    const negMin: u32 = comptime (1 << 31) | (~posMax >> 1);

    if (parsing.optionalOperator("*", line) == '*') {
        // Save for error messages
        const asteriskLinePos = line.tokenStart;

        if (depth == 1) {
            try diag.msg("implicit array lengths cannot be nested\n", .{});
            return error.ParseError;
        }
        _ = try parsing.expectOperator(".", line, diag);

        const token = line.next() orelse {
            try diag.msg("expected directive\n", .{});
            return error.ParseError;
        };
        const directive = stringMap.get(token) orelse {
            try diag.msg("expected directive\n", .{});
            return error.ParseError;
        };

        var returnedArray: []u8 = undefined;

        switch (directive) {
            Directive.word => returnedArray = try parseStaticData(u32, allocator, 1, line, diag),
            Directive.half => returnedArray = try parseStaticData(u16, allocator, 1, line, diag),
            Directive.byte => returnedArray = try parseStaticData(u8, allocator, 1, line, diag),
            Directive.string => returnedArray = try parsing.parseString(allocator, line, diag),
            else => {
                try diag.msg("expected 'word', 'half', 'byte', or 'string'\n", .{});
                return error.ParseError;
            },
        }

        if (returnedArray.len > posMax) {
            line.tokenStart = asteriskLinePos;
            try diag.msg("array length is out of range", .{});
            return error.ParseError;
        }

        // Take ownership of slice to hopefully avoid unnecessary heap calls
        var combinedArray = std.ArrayList(u8).fromOwnedSlice(allocator, returnedArray);
        defer combinedArray.deinit();

        // Prepend size of array in bytes to slice
        try combinedArray.insertSlice(0, parsing.uintAsU8Slice(T, @intCast(returnedArray.len)));

        // Caller takes ownership
        return try combinedArray.toOwnedSlice();
    }

    var array = try std.ArrayList(u8).initCapacity(allocator, baseArrayCap);
    defer array.deinit();

    while (line.next()) |token| {
        const negated = if (parsing.optionalOperator("-", line) == '-') true else false;

        var val: u32 = parsing.parseInteger(token) catch |err| {
            switch (err) {
                error.Unexpected => try diag.msg("expected value\n", .{}),
                error.ValueNotEncodable => try diag.msg("value is too large\n", .{}),
            }
            return error.ParseError;
        };

        if (negated) val = ~val + 1;

        if ((negated and val < negMin) or val > posMax) {
            try diag.msg("value is out of range\n", .{});
            return error.ParseError;
        }

        try array.appendSlice(parsing.uintAsU8Slice(T, @as(T, @truncate(val))));

        if (parsing.optionalOperator(",", line)) |c| switch (c) {
            ',' => {},
            '\n' => return array.toOwnedSlice(),
            else => unreachable,
        } else {
            try diag.msg("expected ',' or EOL\n", .{});
            return error.ParseError;
        }
    }

    try diag.msg("expected value\n", .{});
    return error.ParseError;
}

// ================================================================
//   TESTS
// ================================================================

test "parseBssDeclaration" {
    var diag = try Diagnostic.init();
    var line = Tokenizer.init("label 1024");
    const res = try parseBssDeclaration(&line, &diag);
    try std.testing.expectEqualSlices(u8, "label", res.label);
    try std.testing.expectEqual(1024, res.size);
}

test "parseAlignDirective" {
    var diag = try Diagnostic.init();
    var line = Tokenizer.init("4");
    const res = try parseAlignDirective(&line, &diag);
    try std.testing.expectEqual(4, res);
}

test "parseAlignDirective -- Non power of 2" {
    var diag = try Diagnostic.init();
    var line = Tokenizer.init("7");
    try std.testing.expectError(error.ParseError, parseAlignDirective(&line, &diag));
}

test "parseStaticData -- .word" {
    const ta = std.testing.allocator;
    var diag = try Diagnostic.init();
    var line = Tokenizer.init("0x33221100, 0x77665544");
    const array = try parseStaticData(u32, ta, 0, &line, &diag);
    defer ta.free(array);
    try std.testing.expectEqualSlices(u8, ([8]u8{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77 })[0..], array);
}

test "parseStaticData -- .word with implicit array length" {
    const ta = std.testing.allocator;
    var diag = try Diagnostic.init();
    var line = Tokenizer.init("* .word 0x33221100, 0x77665544");
    const array = try parseStaticData(u32, ta, 0, &line, &diag);
    std.debug.print("{s}\n", .{diag.text.slice()});
    defer ta.free(array);
    try std.testing.expectEqualSlices(u8, ([12]u8{ 0x08, 0x00, 0x00, 0x00, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77 })[0..], array);
}

test "parseStaticData -- .byte" {
    const ta = std.testing.allocator;
    var diag = try Diagnostic.init();
    var line = Tokenizer.init("0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77");
    const array = try parseStaticData(u8, ta, 0, &line, &diag);
    defer ta.free(array);
    try std.testing.expectEqualSlices(u8, ([8]u8{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77 })[0..], array);
}

test "parseStaticData -- .byte with implicit array length" {
    const ta = std.testing.allocator;
    var diag = try Diagnostic.init();
    var line = Tokenizer.init("* .byte 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77");
    const array = try parseStaticData(u8, ta, 0, &line, &diag);
    std.debug.print("{s}\n", .{diag.text.slice()});
    defer ta.free(array);
    try std.testing.expectEqualSlices(u8, ([9]u8{ 0x08, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77 })[0..], array);
}

test "parseStaticData -- .string" {
    const ta = std.testing.allocator;
    var diag = try Diagnostic.init();
    var line = Tokenizer.init("\"a string\"");
    const array = try parsing.parseString(ta, &line, &diag);
    defer ta.free(array);
    try std.testing.expectEqualSlices(u8, "a string", array);
}
