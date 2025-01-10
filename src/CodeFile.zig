const std = @import("std");
const ascii = std.ascii;

const Reader = std.io.AnyReader;

const Tokenizer = @import("Tokenizer.zig");
const Instruction = @import("Instruction.zig");

const directive = @import("directive.zig");

const parsing = @import("parsing.zig");
const Diagnostic = parsing.Diagnostic;

const Self = @This();

const Symbol = struct {
    refs: usize,
    sym: []const u8,
};

const TableEntry = struct {
    symbolIndex: u32,
    offset: u32,
};

const baseBufferCap = 1024;
const baseTableCap = 64;
const baseSectionCap = 4;

const AsmSectionType = enum { data, text };

const AsmSection = struct {
    sectionLabelIndex: ?u32,
    labels: std.ArrayList(TableEntry),
    relocationTable: std.ArrayList(TableEntry),
    exportedSymbols: std.ArrayList(u32),
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator, labelIndex: ?u32) !AsmSection {
        return AsmSection{
            .sectionLabelIndex = labelIndex,
            .labels = try std.ArrayList(TableEntry).initCapacity(allocator, baseTableCap),
            .relocationTable = try std.ArrayList(TableEntry).initCapacity(allocator, baseTableCap),
            .exportedSymbols = try std.ArrayList(u32).initCapacity(allocator, baseTableCap),
            .buffer = try std.ArrayList(u8).initCapacity(allocator, baseBufferCap),
        };
    }

    pub fn deinit(self: *AsmSection) void {
        self.buffer.deinit();
        self.labels.deinit();
        self.relocationTable.deinit();
        self.exportedSymbols.deinit();
    }
};

bssTable: std.ArrayList(TableEntry),

dataSections: std.ArrayList(AsmSection),
textSections: std.ArrayList(AsmSection),
currSection: ?struct { sectionType: AsmSectionType, sectionPtr: *AsmSection },

externalSymbols: std.ArrayList(u32),
exportedSymbols: std.ArrayList(u32),

symbolTable: std.ArrayList(Symbol),

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !Self {
    return Self{
        .allocator = allocator,
        .bssTable = try std.ArrayList(TableEntry).initCapacity(allocator, baseTableCap),
        .dataSections = try std.ArrayList(AsmSection).initCapacity(allocator, baseSectionCap),
        .textSections = try std.ArrayList(AsmSection).initCapacity(allocator, baseSectionCap),
        .exportedSymbols = try std.ArrayList(u32).initCapacity(allocator, baseTableCap),
        .externalSymbols = try std.ArrayList(u32).initCapacity(allocator, baseTableCap),
        .symbolTable = try std.ArrayList(Symbol).initCapacity(allocator, baseTableCap),
        .currSection = null,
    };
}

///
pub fn deinit(self: *Self) void {
    self.bssTable.deinit();
    self.externalSymbols.deinit();
    self.exportedSymbols.deinit();
    for (self.symbolTable.items) |symbol| {
        self.allocator.free(symbol.sym);
    }
    for (self.dataSections.items) |*section| {
        section.deinit();
    }
    self.dataSections.deinit();
    for (self.textSections.items) |*section| {
        section.deinit();
    }
    self.textSections.deinit();
    self.symbolTable.deinit();
}

pub fn assemble(self: *Self, reader: Reader, diag: *Diagnostic) !void {
    var lineBuf = std.BoundedArray(u8, 512);

    while (reader.streamUntilDelimiter(lineBuf.writer(), "\n")) {
        if (lineBuf.constSlice().len == 0) continue;

        var line = Tokenizer.init(lineBuf.slice);

        if (!ascii.isWhitespace(lineBuf.constSlice()[0])) {
            try self.parseLocalLabel(&line, diag);
        }

        try self.parseLine(&line, diag);

        lineBuf.resize(0);
    }

    // make sure exported symbols are defined
    // make sure external symbols are used
    // resolve branches within file
    // remove exhausted symbols
}

fn parseLocalLabel(self: *Self, line: *Tokenizer, diag: *Diagnostic) !void {
    var section: AsmSection = self.currSection orelse {
        diag.msg("section type not specified\n", .{});
        return error.ParseError;
    };

    const label = try parsing.parseLabel(line);

    _ = parsing.expectOperator(":", line, diag);

    const symbolIndex = try self.addSymbolFromDeclaration(label, diag);
    try section.labels.append(TableEntry{
        .symbolIndex = symbolIndex,
        .offset = section.buffer.items.len,
    });
}

fn parseLine(self: *Self, line: *Tokenizer, diag: *Diagnostic) !void {
    const token = line.next() orelse return;

    // Process directive
    if (token[0] == '.') {
        self.processDirective(&line, diag);
        if (line.next()) |_| {
            try diag.msg("expected EOL\n", .{});
            return error.ParseError;
        }
        return;
    }

    const section: AsmSection = self.currSection orelse {
        diag.msg("section type not specified\n", .{});
        return error.ParseError;
    };
    if (section != self.textSections) {
        diag.msg("instructions must go within .text section\n", .{});
        return error.ParseError;
    }

    // Process instruction
    line.putBack();
    if (try Instruction.encode(line, diag)) |inst| {
        // Relocation table entry
        if (inst.reloc) |reloc| {
            const symbolIndex = self.findOrAddSymbol(reloc);
            section.relocationTable.append(.{
                .symbolIndex = symbolIndex,
                .offset = section.buffer.items.len,
            });
        }

        section.buffer.appendSlice(parsing.uintAsU8Slice(u32, inst.encoding));
        if (inst.extension) |extension| {
            section.buffer.appendSlice(parsing.uintAsU8Slice(u32, extension));
        }
    }
}

fn processDirective(self: *Self, line: *Tokenizer, diag: *Diagnostic) !void {
    const token = line.next() orelse {
        try diag.msg("expected directive\n", .{});
        return error.ParseError;
    };

    if (directive.stringMap.get(token)) |dir| switch (dir) {
        .data => {
            var labelIndex: ?u32 = null;
            if (parsing.parseSymbol(line, diag)) |label| {
                labelIndex = try self.addSymbolFromDeclaration(label, diag);
            } else |err| {
                if (err != error.ParseError) return err;
            }
            try self.dataSections.append(try AsmSection.init(self.allocator, labelIndex));
            self.currSection = .{ .sectionType = .data, .sectionPtr = &self.dataSections.items[self.dataSections.items.len - 1] };
        },
        .text => {
            var labelIndex: ?u32 = null;
            if (parsing.parseSymbol(line, diag)) |label| {
                labelIndex = try self.addSymbolFromDeclaration(label, diag);
            } else |err| {
                if (err != error.ParseError) return err;
            }
            try self.textSections.append(try AsmSection.init(self.allocator, labelIndex));
            self.currSection = .{ .sectionType = .text, .sectionPtr = &self.textSections.items[self.textSections.items.len - 1] };
        },
        .bss => {
            self.currSection = null;
            const res = try directive.parseBssDeclaration(line, diag);
            const symbolIndex = try self.addSymbolFromDeclaration(res.label, diag);
            try self.bssTable.append(TableEntry{ .symbolIndex = symbolIndex, .offset = res.size });
        },
        .@"align" => {
            var section = try self.fetchCurrentSection(diag);
            const alignment = try directive.parseAlignDirective(line, diag);
            const bytesToAdd = alignment - (section.buffer.items.len % alignment);
            try section.buffer.appendNTimes(0, bytesToAdd);
        },
        .@"export" => {
            const symbol = try parsing.parseSymbol(line, diag);
            const symbolIndex = try self.findOrAddSymbol(symbol);
            try self.exportedSymbols.append(symbolIndex);
        },
        .@"extern" => {
            const symbol = try parsing.parseSymbol(line, diag);
            const symbolIndex = try self.addSymbolFromDeclaration(symbol, diag);
            try self.externalSymbols.append(symbolIndex);
        },
        .word => _ = {
            var section: *AsmSection = try self.fetchCurrentSection(diag);
            try section.buffer.appendSlice(try directive.parseStaticData(u32, self.allocator, 0, line, diag));
        },
        .half => {
            var section: *AsmSection = try self.fetchCurrentSection(diag);
            try section.buffer.appendSlice(try directive.parseStaticData(u16, self.allocator, 0, line, diag));
        },
        .byte => {
            var section: *AsmSection = try self.fetchCurrentSection(diag);
            try section.buffer.appendSlice(try directive.parseStaticData(u8, self.allocator, 0, line, diag));
        },
        .string => {
            var section: *AsmSection = try self.fetchCurrentSection(diag);
            try section.buffer.appendSlice(try parsing.parseString(self.allocator, line, diag));
        },
    } else {
        try diag.msg("expected directive\n", .{});
        return error.ParseError;
    }

    // Catch extraneous tokens after otherwise correct directives
    if (line.next()) |_| {
        try diag.msg("expected EOL\n", .{});
        return error.ParseError;
    }
}

inline fn fetchCurrentSection(self: Self, diag: *Diagnostic) !*AsmSection {
    if (self.currSection) |currSection| {
        return currSection.sectionPtr;
    } else {
        try diag.msg("section type not specified\n", .{});
        return error.ParseError;
    }
}

const SymbolError = error{DuplicateSymbol};

fn addSymbolFromDeclaration(self: *Self, str: []const u8, diag: *Diagnostic) !u32 {
    for (0.., self.symbolTable.items) |i, *symbol| {
        if (std.mem.eql(u8, symbol.sym, str)) {
            if (self.symbolIsDuplicate(@intCast(i))) {
                try diag.msg("redeclaration of symbol\n", .{});
                return error.ParseError;
            }
            symbol.refs += 1;
            return @intCast(i);
        }
    }
    var newSymbol: []u8 = try self.allocator.alloc(u8, str.len);
    @memcpy(newSymbol[0..str.len], str);
    try self.symbolTable.append(.{ .refs = 1, .sym = newSymbol[0..str.len] });
    return @intCast(self.symbolTable.items.len - 1);
}

fn symbolIsDuplicate(self: Self, symbolIndex: u32) bool {
    for (self.bssTable.items) |label| {
        if (label.symbolIndex == symbolIndex) return true;
    }
    for (self.dataSections.items) |section| {
        for (section.labels.items) |label| {
            if (label.symbolIndex == symbolIndex) return true;
        }
    }
    for (self.textSections.items) |section| {
        for (section.labels.items) |label| {
            if (label.symbolIndex == symbolIndex) return true;
        }
    }
    return false;
}

fn findOrAddSymbol(self: *Self, str: []const u8) !u32 {
    for (0.., self.symbolTable.items) |i, *symbol| {
        if (std.mem.eql(u8, symbol.sym, str)) {
            symbol.refs += 1;
            return @intCast(i);
        }
    }
    var newSymbol: []u8 = try self.allocator.alloc(u8, str.len);
    @memcpy(newSymbol[0..str.len], str);
    try self.symbolTable.append(.{ .refs = 1, .sym = newSymbol[0..str.len] });
    return @intCast(self.symbolTable.items.len - 1);
}

// ================================================================
//   TESTS
// ================================================================

test "addSymbolFromDeclaration, findOrAddSymbol" {
    const ta = std.testing.allocator;
    var file: Self = try Self.init(ta);
    defer file.deinit();
    var diag = try Diagnostic.init();
    _ = try file.addSymbolFromDeclaration("symb0", &diag);
    try std.testing.expectEqual(1, file.symbolTable.items.len);
    try std.testing.expectEqual(1, file.symbolTable.items[0].refs);
    try std.testing.expectEqualDeep("symb0", file.symbolTable.items[0].sym);
    _ = try file.addSymbolFromDeclaration("symb1", &diag);
    try std.testing.expectEqual(2, file.symbolTable.items.len);
    try std.testing.expectEqual(1, file.symbolTable.items[1].refs);
    try std.testing.expectEqualDeep("symb1", file.symbolTable.items[1].sym);
    _ = try file.findOrAddSymbol("symb2");
    try std.testing.expectEqual(3, file.symbolTable.items.len);
    try std.testing.expectEqual(1, file.symbolTable.items[2].refs);
    try std.testing.expectEqualDeep("symb2", file.symbolTable.items[2].sym);
    try std.testing.expectEqual(2, file.findOrAddSymbol("symb2"));
}

test "symbolIsDuplicate + .data + .text" {
    const ta = std.testing.allocator;
    var file: Self = try Self.init(ta);
    defer file.deinit();
    var diag = try Diagnostic.init();
    const index0 = try file.addSymbolFromDeclaration("symb0", &diag);
    try file.bssTable.append(TableEntry{ .offset = 0, .symbolIndex = index0 });
    try std.testing.expect(file.symbolIsDuplicate(index0));
    var line = Tokenizer.init("data");
    try file.processDirective(&line, &diag);
    const index1 = try file.addSymbolFromDeclaration("symb1", &diag);
    try file.dataSections.items[0].labels.append(TableEntry{ .offset = 0, .symbolIndex = index1 });
    try std.testing.expect(file.symbolIsDuplicate(index1));
    line = Tokenizer.init("text");
    try file.processDirective(&line, &diag);
    const index2 = try file.addSymbolFromDeclaration("symb2", &diag);
    try file.textSections.items[0].labels.append(TableEntry{ .offset = 0, .symbolIndex = index2 });
    try std.testing.expect(file.symbolIsDuplicate(index2));
}

test "processDirective -- missing directive" {
    const ta = std.testing.allocator;
    var file: Self = try Self.init(ta);
    defer file.deinit();
    var diag = try Diagnostic.init();
    var line = Tokenizer.init("");
    try std.testing.expectError(error.ParseError, file.processDirective(&line, &diag));
}

test "processDirective -- .bss with missing/extra tokens" {
    const ta = std.testing.allocator;
    var file: Self = try Self.init(ta);
    defer file.deinit();
    var diag = try Diagnostic.init();
    var line = Tokenizer.init("bss");
    try std.testing.expectError(error.ParseError, file.processDirective(&line, &diag));
    line = Tokenizer.init("bss label");
    try std.testing.expectError(error.ParseError, file.processDirective(&line, &diag));
    line = Tokenizer.init("bss label 1024!");
    try std.testing.expectError(error.ParseError, file.processDirective(&line, &diag));
}

test "processDirective -- .bss success" {
    const ta = std.testing.allocator;
    var file: Self = try Self.init(ta);
    defer file.deinit();
    var diag = try Diagnostic.init();
    var line = Tokenizer.init("bss label0 1024");
    try file.processDirective(&line, &diag);
    try std.testing.expectEqual(1, file.symbolTable.items.len);
    try std.testing.expectEqual(0, file.bssTable.items[0].symbolIndex);
    try std.testing.expectEqual(1024, file.bssTable.items[0].offset);
    line = Tokenizer.init("bss label1 2048");
    try file.processDirective(&line, &diag);
    try std.testing.expectEqual(2, file.symbolTable.items.len);
    try std.testing.expectEqual(1, file.bssTable.items[1].symbolIndex);
    try std.testing.expectEqual(2048, file.bssTable.items[1].offset);
}
