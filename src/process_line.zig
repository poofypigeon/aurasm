const std = @import("std");
const ascii = std.ascii;

const encodeInstruction = @import("encode_instruction.zig").encodeInstruction;


const AsmLineContentTag = enum {
    SECTION,
    EXPORT,
    LABEL,
    INSTRUCTION,
    BYTE,
    HWORD,
    WORD,
    ASCII,
    ALIGN,
};

const AsmLineContent = union(AsmLineContentTag) {
    SECTION: bool,
    EXPORT: bool,
    LABEL: []u8,
    INSTRUCTION: Instruction,
    BYTE: u8,
    HWORD: u16,
    WORD: u32,
    ASCII: []u8,
    ALIGN: u32,
};

pub fn processLine(line: [:0]const u8) !?AsmLineContent {
    if (line.len == 0) return null;
    if (ascii.isWhitespace(line[0])) return try encodeInstruction(line);
    // if (line[0] == '.') return try processDirective(line[1..], symbols);
    // return try processLabel(line);
    return null;
}
//
// fn encodeInstruction(line: [:0]const u8) !AsmLineContent {
//     var tokens = Tokenizer.init(line);
//     const mnemonicString = tokens.next() catch return null;
//     perf.parseMnemonic(line, line.len);
//
//
//     return error.InvalidMnemonic;
// }

// fn processDirective(line: [:0]const u8, symbols: std.ArrayList(std.ArrayList(u8))) !?AsmLineContent {
//     var tokens = Tokenizer.init(line);
//     const directive = tokens.next();
//     if (std.mem.eql(".data", directive)) return null;
// }
//
// fn processLabel() void {}
//

// test {
//     const line = "add r1, r2, r2 LSL 4";
//     var tokens = Tokenizer.init(line);
//     const tok = try tokens.next();
//     const mnemonic = perf.parseMnemonic(tok.ptr, tok.len);
//     try std.testing.expect(perf.ADD == mnemonic);
// }
