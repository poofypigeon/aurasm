const std = @import("std");
const ascii = std.ascii;

const Allocator = std.mem.Allocator;
const Reader = std.io.AnyReader;

const Tokenizer = @import("tokenizer.zig");
const Diagnostic = @import("parsing.zig").Diagnostic;
const Instruction = @import("encode_instruction.zig").Instruction;
const encodeInstruction = @import("encode_instruction.zig").encodeInstruction;

const parsing = @import("parsing.zig");

const Self = @This();

const Symbol = std.ArrayList(u8);

const TableEntry = struct {
    symbolTableIndex: u32,
    offset: u32,
};

const CodeSection = struct {
    buffer: std.ArrayList(u8),
    labels: std.ArrayList(TableEntry),
    relocationTable: std.ArrayList(TableEntry),
    exportedSymbols: std.ArrayList(u32),
};

bssTable: std.ArrayList(TableEntry),

dataSection: CodeSection,
textSection: CodeSection,
currSection: ?*CodeSection = null,

externalSymbols: std.ArrayList(u32),

/// holds indices into symbol table of exported symbols
symbolTable: std.ArrayList(struct { refs: usize, sym: Symbol }),

allocator: Allocator,

const Directive = enum {
    data,
    text,
    bss,
    // import,
    @"extern",
    @"export",
    @"align",
    word,
    half,
    byte,
    string,
    size,
    // macro, endm,
};

const directiveMap = std.StaticStringMap(Directive).initComptime(.{
    .{ "data", Directive.data },
    .{ "text", Directive.text },
    .{ "bss", Directive.bss },
    // .{"import", Directive.import},
    .{ "extern", Directive.@"extern" },
    .{ "export", Directive.@"export" },
    .{ "align", Directive.@"align" },
    .{ "word", Directive.word },
    .{ "half", Directive.half },
    .{ "byte", Directive.byte },
    .{ "string", Directive.string },
});

pub fn init(allocator: Allocator) Self {
    return Self{
        .bssTable = std.ArrayList(TableEntry).init(allocator),
        .dataSection = CodeSection{
            .buffer = std.ArrayList(u8).init(allocator),
            .labels = std.ArrayList(TableEntry).init(allocator),
            .relocationTable = std.ArrayList(TableEntry).init(allocator),
            .exportedSymbols = std.ArrayList(u32).init(allocator),
        },
        .textSection = CodeSection{
            .buffer = std.ArrayList(u8).init(allocator),
            .labels = std.ArrayList(TableEntry).init(allocator),
            .relocationTable = std.ArrayList(TableEntry).init(allocator),
            .exportedSymbols = std.ArrayList(u32).init(allocator),
        },
        .externalSymbols = std.ArrayList(u32),
        .symbolTable = std.ArrayList(struct {
            refs: usize,
            sym: Symbol,
        }).init(allocator),
        .allocator = allocator,
    };
}

pub fn process(self: *Self, reader: Reader, diag: *Diagnostic) !void {
    var lineBuf = std.BoundedArray(u8, 256);

    while (reader.streamUntilDelimiter(lineBuf.writer(), "\n")) {
        if (lineBuf.constSlice().len == 0) continue;
        defer lineBuf.resize(0);

        var line = Tokenizer.init();

        // Process label
        if (!ascii.isWhitespace(lineBuf.constSlice()[0])) {
            try self.processLabel(&line, diag);
        }

        const token = line.next() orelse continue;

        // Process directive
        if (token[0] == '.') {
            self.processDirective(&line, diag);
            if (line.next()) |_| {
                try diag.msg("expected EOL\n", .{});
                return error.ParseError;
            }
            continue;
        }

        const section: CodeSection = self.currSection orelse {
            diag.msg("section type not specified\n", .{});
            return error.ParseError;
        };
        if (section != self.textSection) {
            diag.msg("instructions must go within .text section\n", .{});
            return error.ParseError;
        }

        // Process instruction
        line.putBack();
        if (try encodeInstruction(line, diag)) |inst| {
            // Relocation table entry
            if (inst.reloc) |reloc| {
                const symbolIndex = self.findOrAddSymbol(reloc);
                section.relocationTable.append(.{
                    .symbolTableIndex = symbolIndex,
                    .offset = section.buffer.items.len,
                });
            }

            section.buffer.appendSlice(encodingAsSlice(inst.encoding));
            if (inst.extension) |ext| {
                section.buffer.appendSlice(encodingAsSlice(ext));
            }
        }
    }

    // make sure exported symbols are defined
    // make sure external symbols are used
    // resolve branches within file
    // remove exhausted symbols
}

fn encodingAsSlice(encoding: u32) []const u8 {
    const littleEndian = std.mem.nativeToLittle(u32, encoding);
    return @as(*const [4]u8, @ptrCast(&littleEndian)).*[0..];
}

const SymbolError = error{DuplicateSymbol};

fn addLabel(self: *Self, str: []const u8) !u32 {
    for (0.., self.symbolTable) |i, symbol| {
        if (std.mem.eql(u8, symbol, str)) {
            if (labelIsDuplicate(i)) return error.DuplicateSymbol;
            symbol.refs += 1;
            return i;
        }
    }
    var newSymbol = std.ArrayList(u8).init(self.allocator);
    try newSymbol.appendSlice(str);
    try self.symbolTable.append(.{ .refs = 1, .sym = newSymbol });
    return self.symbolTable.items.len - 1;
}

fn labelIsDuplicate(self: Self, symbolIndex: u32) bool {
    for (self.bssTable) |label| {
        if (label.symbolTableIndex == symbolIndex) return true;
    }
    for (self.dataSection.labels) |label| {
        if (label.symbolTableIndex == symbolIndex) return true;
    }
    for (self.textSection.labels) |label| {
        if (label.symbolTableIndex == symbolIndex) return true;
    }
    return false;
}

fn findOrAddSymbol(self: *Self, str: []const u8) !u32 {
    for (0.., self.symbolTable) |i, symbol| {
        if (std.mem.eql(u8, symbol, str)) {
            symbol.refs += 1;
            return i;
        }
    }
    var newSymbol = std.ArrayList(u8).init(self.allocator);
    try newSymbol.appendSlice(str);
    try self.symbolTable.append(.{ .refs = 1, .sym = newSymbol });
    return self.symbolTable.items.len - 1;
}

fn processLabel(self: *Self, line: *Tokenizer, diag: *Diagnostic) !void {
    var section: CodeSection = self.currSection orelse {
        diag.msg("section type not specified\n", .{});
        return error.ParseError;
    };

    const token = line.next() orelse return;
    if (!(parsing.tokenIsLabel(token))) {
        diag.msg("expected label\n", .{});
        return error.ParseError;
    }

    _ = parsing.expectOperator(":", line, diag);

    const symbolIndex = self.addLabel(token) catch |err| switch (err) {
        error.DuplicateSymbol => {
            diag.msg("redeclaration of symbol\n", .{});
            return error.ParseError;
        },
        else => return err,
    };
    try section.labels.append(TableEntry{
        .symbolTableIndex = symbolIndex,
        .offset = section.buffer.items.len,
    });
}

fn processDirective(self: *Self, line: *Tokenizer, diag: *Diagnostic) !void {
    const token = line.next() orelse {
        diag.msg("expected directive\n", .{});
        return error.ParseError;
    };

    const dir = directiveMap.get(token) orelse {
        diag.msg("expected directive\n", .{});
        return error.ParseError;
    };

    switch (dir) {
        Directive.data => self.currSection = &self.dataSection,
        Directive.text => self.currSection = &self.textSection,
        Directive.bss => try self.bssDirective(&line, diag),
        Directive.@"align" => try self.alignDirective(&line, diag),
        else => {},
    }
}

fn bssDirective(self: *Self, line: *Tokenizer, diag: *Diagnostic) !void {
    // Parse label
    const label = line.next() orelse {
        try diag.msg("expected label\n", .{});
        return error.ParseError;
    };
    if (!parsing.tokenIsLabel(label)) {
        try diag.msg("expected label\n", .{});
        return error.ParseError;
    }

    // Parse .bss segment size
    const token = line.next() orelse {
        try diag.msg("expected .bss segment size\n", .{});
        return error.ParseError;
    };
    const segmentSize = parsing.parseInteger(token) catch |err| {
        switch (err) {
            error.Unexpected => try diag.msg("expected .bss segment size\n", .{}),
            error.ValueNotEncodable => try diag.msg("value too large", .{}),
        }
        return err;
    };

    const symbolIndex = self.addLabel(label) catch |err| switch (err) {
        error.DuplicateSymbol => {
            diag.msg("redeclaration of symbol\n", .{});
            return error.ParseError;
        },
        else => return err,
    };

    try self.bssTable.append(TableEntry{
        .symbolTableIndex = symbolIndex,
        .offset = segmentSize,
    });
}

fn alignDirective(self: *Self, line: *Tokenizer, diag: *Diagnostic) !void {
    var section: CodeSection = self.currSection orelse {
        diag.msg("section type not specified\n", .{});
        return error.ParseError;
    };

    // Parse alignment value
    const token = line.next() orelse {
        try diag.msg("expected alignment value\n", .{});
        return error.ParseError;
    };
    const alignment = parsing.parseInteger(token) catch |err| {
        switch (err) {
            error.Unexpected => try diag.msg("expected alignment value\n", .{}),
            error.ValueNotEncodable => try diag.msg("value too large", .{}),
        }
        return err;
    };

    if (@popCount(alignment) != 1) {
        diag.msg("alignment value must be a power of 2", .{});
        return error.ParseError;
    }

    const bytesToAdd = alignment - (self.buffer.items.len % alignment);
    section.buffer.writer().writeByteNTimes(0, bytesToAdd);
}

fn exportDirective(self: *Self, line: Tokenizer, diag: *Diagnostic) !void {
    var section: CodeSection = self.currSection orelse {
        diag.msg("section type not specified\n", .{});
        return error.ParseError;
    };

    // Parse label
    const token = line.next() orelse {
        try diag.msg("expected label\n", .{});
        return error.ParseError;
    };
    if (!parsing.tokenIsLabel(token)) {
        try diag.msg("expected label\n", .{});
        return error.ParseError;
    }

    const symbolIndex = try self.findOrAddSymbol(token);
    section.exportedSymbols.append(symbolIndex);
}
