const std = @import("std");
const ascii = std.ascii;

const globals = @import("globals.zig");

/// Processes a u8 slice into tokens.
/// Any collection of consecutive alphanumeric characters are considered tokens.
/// Any non-alphanumeric characters besides whitespace are additionally considered distinct tokens.
pub const Tokenizer = struct {
    line: [:0]const u8,
    tokenStart: u32,
    tokenEnd: u32,
    again: bool,

    pub fn init(line: [:0]const u8) Tokenizer {
        return Tokenizer{
            .line = line,
            .tokenStart = 0,
            .tokenEnd = 0,
            .again = false,
        };
    }

    /// Returns next token in slice.
    /// If there are no more tokens to be read, returns error.EndOfLine
    pub fn next(self: *Tokenizer) ?[]const u8 {
        if (self.again) {
            self.again = false;
            return self.line[self.tokenStart..self.tokenEnd];
        }

        if (self.tokenEnd == self.line.len) {
            self.tokenStart = self.tokenEnd;
            return null;
        }

        // Skip whitespace
        while (ascii.isWhitespace(self.line[self.tokenEnd])) : (self.tokenEnd += 1) {}
        self.tokenStart = self.tokenEnd;
        globals.columnNumber = self.tokenEnd;
        if (self.tokenStart == self.line.len) return null;

        // Treat comments as end-of-line
        if (self.line[self.tokenStart] == ';') return null;

        // Any non-alphanumeric characters besides whitespace and underscores are considered tokens
        if (!isLabelChar(self.line[self.tokenEnd])) {
            self.tokenEnd += 1;
            return self.line[self.tokenStart..self.tokenEnd];
        }

        // Consume characters until a non-label character or underscore is encountered
        while (isLabelChar(self.line[self.tokenEnd])) : (self.tokenEnd += 1) {}
        return self.line[self.tokenStart..self.tokenEnd];
    }

    pub inline fn putBack(self: *Tokenizer) void {
        self.again = true;
    }
};

inline fn isLabelChar(c: u8) bool {
    return ascii.isAlphanumeric(c) or c == '_';
}
