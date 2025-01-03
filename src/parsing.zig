const std = @import("std");
const ascii = std.ascii;

const Tokenizer = @import("tokenizer.zig");

const ParseError = error{ParseError};

pub const Diagnostic = struct {
    text: std.BoundedArray(u8, 64),

    pub fn init(allocator: std.mem.Allocator) Diagnostic {
        return Diagnostic{ .text = std.ArrayList(u8).init(allocator) };
    }

    pub inline fn msg(self: *Diagnostic, comptime fmt: []const u8, args: anytype) !void {
        self.text.resize(0) catch unreachable;
        try self.text.writer().print(fmt, args);
    }
};

const OperandTag = enum { reg, imm, label };
pub const Operand = union(OperandTag) { reg: u4, imm: u32, label: []const u8 };

const OperandError = error{ Unexpected, ValueNotEncodable };

pub fn parseOperand(token: []const u8) !Operand {
    switch (token[0]) {
        'r', 'R' => {
            if (token.len > 3) return error.Unexpected;
            const regNum = try parseDec(token[1..]);
            if (regNum > 0b1111) return error.Unexpected;
            return Operand{ .reg = @intCast(regNum) };
        },
        's' => if (token.len == 2 and token[1] == 'p') return Operand{ .reg = 0b1110 },
        'S' => if (token.len == 2 and token[1] == 'P') return Operand{ .reg = 0b1110 },
        'l' => if (token.len == 2 and token[1] == 'r') return Operand{ .reg = 0b1111 },
        'L' => if (token.len == 2 and token[1] == 'R') return Operand{ .reg = 0b1111 },
        '0' => {
            if (token.len == 1) return Operand{ .imm = 0 };
            if (token.len < 3) return error.Unexpected;
            if (token[1] == 'x') return Operand{ .imm = try parseHex(token[2..]) };
            if (token[1] == 'b') return Operand{ .imm = try parseBin(token[2..]) };
            return error.Unexpected;
        },
        else => {
            if (ascii.isDigit(token[0])) return Operand{ .imm = try .parseDec(token) };
            if (!(ascii.isAlphabetic(token[0]) or token[0] == '_')) return error.Unexpected;
        },
    }
    return Operand{ .label = token };
}

inline fn expectRegister(line: *Tokenizer, diag: *Diagnostic) !u4 {
    const token = line.next() orelse {
        try diag.msg("expected register\n", .{});
        return error.ParseError;
    };
    if (parseOperand(token)) |op| switch (op) {
        .reg => |reg| return reg,
        else => {
            try diag.msg("expected register\n", .{});
            return error.ParseError;
        },
    } else |err| switch (err) {
        else => {
            try diag.msg("expected register\n", .{});
            return error.ParseError;
        },
    }
}

inline fn expectRegisterOrValue(line: *Tokenizer, diag: *Diagnostic) !Operand {
    const token = line.next() orelse {
        try diag.msg("expected register or value\n", .{});
        return error.ParseError;
    };
    if (parseOperand(token)) |op| switch (op) {
        .reg => |reg| return Operand{ .reg = reg },
        .imm => |imm| return Operand{ .imm = imm },
        else => {
            try diag.msg("expected register or value\n", .{});
            return error.ParseError;
        },
    } else |err| switch (err) {
        error.Unexpected => {
            try diag.msg("expected register or value\n", .{});
            return error.ParseError;
        },
        else => return err,
    }
}

fn operatorListStr(comptime list: []const u8) []const u8 {
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

inline fn expectOperator(comptime expect: []const u8, line: *Tokenizer, diag: *Diagnostic) !u8 {
    // Operator list fomatted for error message
    const expectListString = comptime operatorListStr(expect);

    const token = line.next() orelse {
        try diag.msg("expected {s}\n", .{expectListString});
        return error.ParseError;
    };
    inline for (expect) |c| if (token[0] == c) return c;

    // Token not in operator list
    try diag.msg("expected " ++ expectListString ++ "\n", .{});
    return error.ParseError;
}

inline fn optionalOperator(comptime expect: []const u8, line: *Tokenizer) ?u8 {
    const token = line.next() orelse return null;
    inline for (expect) |c| if (token[0] == c) return c;
    line.putBack();
    return null;
}

pub inline fn tokenIsLabel(token: []const u8) bool {
    return (ascii.isAlphabetic(token[0]) or token[0] == '_');
}

pub inline fn parseInteger(token: []const u8) !u32 {
    switch (token[0]) {
        '0' => {
            if (token.len == 1) return 0;
            if (token.len < 3) return error.Unexpected;
            if (token[1] == 'x') return try parseHex(token[2..]);
            if (token[1] == 'b') return try parseBin(token[2..]);
            return error.Unexpected;
        },
        else => {
            if (ascii.isDigit(token[0])) return try parseDec(token);
            return error.Unexpected;
        },
    }
}

pub inline fn parseDec(token: []const u8) !u32 {
    var val: u64 = 0;
    for (token) |c| {
        if (c == '_') continue;
        val *= 10;
        val += try u8AsDec(c);
        if (val & (1 << 32) != 0) return error.ValueNotEncodable;
    }
    return @intCast(val);
}

inline fn u8AsDec(c: u8) !u4 {
    if (c >= '0' and c <= '9') return @intCast(c - '0');
    return error.Unexpected;
}

pub inline fn parseHex(token: []const u8) !u32 {
    var val: u64 = 0;
    for (token) |c| {
        if (c == '_') continue;
        val <<= 4;
        val += try u8AsHex(c);
        if (val & (1 << 32) != 0) return error.ValueNotEncodable;
    }
    return @intCast(val);
}

inline fn u8AsHex(c: u8) !u4 {
    if (c >= '0' and c <= '9') return @intCast(c - '0');
    if (c >= 'A' and c <= 'F') return @intCast(c - 'A' + 10);
    if (c >= 'a' and c <= 'f') return @intCast(c - 'a' + 10);
    return error.Unexpected;
}

pub inline fn parseBin(token: []const u8) !u32 {
    var val: u64 = 0;
    for (token) |c| {
        if (c == '_') continue;
        val <<= 1;
        val += try u8AsBin(c);
        if (val & (1 << 32) != 0) return error.ValueNotEncodable;
    }
    return @intCast(val);
}

inline fn u8AsBin(c: u8) !u1 {
    if (c == '0' or c == '1') return @intCast(c - '0');
    return error.Unexpected;
}
