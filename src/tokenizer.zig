//! Processes a u8 slice into tokens.
//! Any collection of consecutive alphanumeric characters are considered tokens.
//! Any non-alphanumeric characters besides whitespace are additionally considered distinct tokens.

const std = @import("std");
const ascii = std.ascii;

const Self = @This();

line: []const u8,
tokenStart: usize,
tokenEnd: usize,
again: bool,

pub fn init(line: []const u8) Self {
    return .{
        .line = line,
        .tokenStart = 0,
        .tokenEnd = 0,
        .again = false,
    };
}

/// Returns the next token in the slice, or null if no tokens remain.
pub fn next(self: *Self) ?[]const u8 {
    if (self.again) {
        self.again = false;
        return self.line[self.tokenStart..self.tokenEnd];
    }

    if (self.tokenEnd == self.line.len) {
        self.tokenStart = self.tokenEnd;
        return null;
    }

    // Skip whitespace
    while (self.tokenEnd < self.line.len) {
        if (!ascii.isWhitespace(self.line[self.tokenEnd])) break;
        self.tokenEnd += 1;
    }
    self.tokenStart = self.tokenEnd;
    if (self.tokenStart == self.line.len) return null;

    // Treat comments as end-of-line
    if (self.line[self.tokenStart] == ';') return null;

    // Any non-alphanumeric characters besides whitespace and underscores are considered tokens
    if (!isLabelChar(self.line[self.tokenEnd])) {
        self.tokenEnd += 1;
        return self.line[self.tokenStart..self.tokenEnd];
    }

    // Consume characters until a non-label character is encountered
    while (self.tokenEnd < self.line.len) {
        if (!isLabelChar(self.line[self.tokenEnd])) break;
        self.tokenEnd += 1;
    }
    return self.line[self.tokenStart..self.tokenEnd];
}

/// The following call to `next` will repeat the previously returned token.
pub inline fn putBack(self: *Self) void {
    self.again = true;
}

inline fn isLabelChar(c: u8) bool {
    return ascii.isAlphanumeric(c) or c == '_';
}
