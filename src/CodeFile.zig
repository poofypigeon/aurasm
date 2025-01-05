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

const SectionType = enum { data, text };

const CodeSection = struct {
    buffer: std.ArrayList(u8),
    labels: std.ArrayList(TableEntry),
    relocationTable: std.ArrayList(TableEntry),
    exportedSymbols: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator) !CodeSection {
        return CodeSection{
            .buffer = try std.ArrayList(u8).initCapacity(allocator, baseBufferCap),
            .labels = try std.ArrayList(TableEntry).initCapacity(allocator, baseTableCap),
            .relocationTable = try std.ArrayList(TableEntry).initCapacity(allocator, baseTableCap),
            .exportedSymbols = try std.ArrayList(u32).initCapacity(allocator, baseTableCap),
        };
    }

    pub fn deinit(self: *CodeSection) void {
        self.buffer.deinit();
        self.labels.deinit();
        self.relocationTable.deinit();
        self.exportedSymbols.deinit();
    }
};

bssTable: std.ArrayList(TableEntry),

dataSection: CodeSection,
textSection: CodeSection,
currSection: ?*CodeSection = null,

externalSymbols: std.ArrayList(u32),
exportedSymbols: std.ArrayList(u32),

symbolTable: std.ArrayList(Symbol),

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !Self {
    return Self{
        .allocator = allocator,
        .bssTable = try std.ArrayList(TableEntry).initCapacity(allocator, baseTableCap),
        .dataSection = try CodeSection.init(allocator),
        .textSection = try CodeSection.init(allocator),
        .exportedSymbols = try std.ArrayList(u32).initCapacity(allocator, baseTableCap),
        .externalSymbols = try std.ArrayList(u32).initCapacity(allocator, baseTableCap),
        .symbolTable = try std.ArrayList(Symbol).initCapacity(allocator, baseTableCap),
    };
}

pub fn deinit(self: *Self) void {
    self.bssTable.deinit();
    self.dataSection.deinit();
    self.textSection.deinit();
    self.externalSymbols.deinit();
    for (self.symbolTable.items) |symbol| {
        self.allocator.free(symbol.sym);
    }
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
    var section: CodeSection = self.currSection orelse {
        diag.msg("section type not specified\n", .{});
        return error.ParseError;
    };

    const label = try parsing.parseLabel(line);

    _ = parsing.expectOperator(":", line, diag);

    const symbolIndex = self.addSymbolFromDeclaration(label) catch |err| switch (err) {
        error.DuplicateSymbol => {
            diag.msg("redeclaration of symbol\n", .{});
            return error.ParseError;
        },
        else => return err,
    };
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
        diag.msg("expected directive\n", .{});
        return error.ParseError;
    };

    if (directive.stringMap.get(token)) |dir| switch (dir) {
        .data => self.currSection = &self.dataSection,
        .text => self.currSection = &self.textSection,
        .bss => {
            self.currSection = null;
            const res = try directive.parseBssDeclaration(&line, diag);
            const symbolIndex = self.addSymbolFromDeclaration(res.label) catch |err| switch (err) {
                error.DuplicateSymbol => {
                    diag.msg("redeclaration of symbol\n", .{});
                    return error.ParseError;
                },
                else => return err,
            };
            try self.bssTable.append(TableEntry{ .symbolIndex = symbolIndex, .offset = res.size });
        },
        .@"align" => {
            var section = fetchCurrentSection(diag);
            const alignment = try directive.parseAlignDirective(&line, diag);
            const bytesToAdd = alignment - (self.buffer.items.len % alignment);
            try section.buffer.appendNTimes(0, bytesToAdd);
        },
        .@"export" => {
            const symbol = try parsing.parseSymbol(&line, diag);
            const symbolIndex = try self.findOrAddSymbol(symbol);
            self.exportedSymbols.append(symbolIndex);
        },
        .@"extern" => {
            const symbol = try parsing.parseSymbol(&line, diag);
            const symbolIndex = try self.addSymbolFromDeclaration(symbol);
            self.externalSymbols.append(symbolIndex);
        },
        .word => _ = {
            var section: *CodeSection = fetchCurrentSection(diag);
            try section.buffer.appendSlice(try directive.parseStaticData(u32, self.allocator, 0, &line, diag));
        },
        .half => {
            var section: *CodeSection = fetchCurrentSection(diag);
            try section.buffer.appendSlice(try directive.parseStaticData(u16, self.allocator, 0, &line, diag));
        },
        .byte => {
            var section: *CodeSection = fetchCurrentSection(diag);
            section.buffer.appendSlice(try directive.parseStaticData(u8, self.allocator, 0, &line, diag));
        },
        .string => {
            var section: *CodeSection = fetchCurrentSection(diag);
            section.buffer.appendSlice(try directive.parseString(u8, self.allocator, &line, diag));
        },
        else => unreachable,
    } else {
        diag.msg("expected directive\n", .{});
        return error.ParseError;
    }
}

inline fn fetchCurrentSection(self: Self, diag: Diagnostic) !*CodeSection {
    return self.currSection orelse {
        diag.msg("section type not specified\n", .{});
        return error.ParseError;
    };
}

const SymbolError = error{DuplicateSymbol};

fn addSymbolFromDeclaration(self: *Self, str: []const u8) !u32 {
    for (0.., self.symbolTable.items) |i, *symbol| {
        if (std.mem.eql(u8, symbol.sym, str)) {
            if (self.symbolIsDuplicate(@intCast(i))) return error.DuplicateSymbol;
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
    for (self.dataSection.labels.items) |label| {
        if (label.symbolIndex == symbolIndex) return true;
    }
    for (self.textSection.labels.items) |label| {
        if (label.symbolIndex == symbolIndex) return true;
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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var file = try Self.init(allocator);
    _ = try file.addSymbolFromDeclaration("symb0");
    try std.testing.expectEqual(1, file.symbolTable.items.len);
    try std.testing.expectEqual(1, file.symbolTable.items[0].refs);
    try std.testing.expectEqualDeep("symb0", file.symbolTable.items[0].sym);
    _ = try file.addSymbolFromDeclaration("symb1");
    try std.testing.expectEqual(2, file.symbolTable.items.len);
    try std.testing.expectEqual(1, file.symbolTable.items[1].refs);
    try std.testing.expectEqualDeep("symb1", file.symbolTable.items[1].sym);
    _ = try file.findOrAddSymbol("symb2");
    try std.testing.expectEqual(3, file.symbolTable.items.len);
    try std.testing.expectEqual(1, file.symbolTable.items[2].refs);
    try std.testing.expectEqualDeep("symb2", file.symbolTable.items[2].sym);
    try std.testing.expectEqual(2, file.findOrAddSymbol("symb2"));
}
