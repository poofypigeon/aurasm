const std = @import("std");
const ascii = std.ascii;

const Reader = std.io.AnyReader;

const Tokenizer = @import("Tokenizer.zig");
const Instruction = @import("Instruction.zig");

const parsing = @import("parsing.zig");
const Diagnostic = parsing.Diagnostic;

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

// Must belong to an ArenaAllocator
allocator: std.heap.Allocator,

const Directive = enum {
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
    // TODO
    // macro, endm,
};

const directiveMap = std.StaticStringMap(Directive).initComptime(.{
    .{ "data", Directive.data },
    .{ "text", Directive.text },
    .{ "bss", Directive.bss },
    .{ "extern", Directive.@"extern" },
    .{ "export", Directive.@"export" },
    .{ "align", Directive.@"align" },
    .{ "word", Directive.word },
    .{ "half", Directive.half },
    .{ "byte", Directive.byte },
    .{ "string", Directive.string },
});

pub fn init(allocator: std.heap.Allocator) !Self {
    return Self{
        .allocator = allocator,
        .bssTable = std.ArrayList(TableEntry).initCapacity(allocator, 64),
        .dataSection = CodeSection{
            .buffer = try std.ArrayList(u8).initCapacity(allocator, 1024),
            .labels = std.ArrayList(TableEntry).initCapacity(allocator, 64),
            .relocationTable = std.ArrayList(TableEntry).initCapacity(allocator, 64),
            .exportedSymbols = std.ArrayList(u32).initCapacity(allocator, 64),
        },
        .textSection = CodeSection{
            .buffer = try std.ArrayList(u8).initCapacity(allocator, 1024),
            .labels = std.ArrayList(TableEntry).initCapacity(allocator, 64),
            .relocationTable = std.ArrayList(TableEntry).initCapacity(allocator, 64),
            .exportedSymbols = std.ArrayList(u32).initCapacity(allocator, 64),
        },
        .externalSymbols = std.ArrayList(u32),
        .symbolTable = std.ArrayList(struct { refs: usize, sym: []const u8 }).initCapacity(allocator, 64),
    };
}

pub fn parse(self: *Self, reader: Reader, diag: *Diagnostic) !void {
    var lineBuf = std.BoundedArray(u8, 512);

    while (reader.streamUntilDelimiter(lineBuf.writer(), "\n")) {
        if (lineBuf.constSlice().len == 0) continue;
        defer lineBuf.resize(0);

        var line = Tokenizer.init();

        // Process label
        if (!ascii.isWhitespace(lineBuf.constSlice()[0])) {
            try self.processLabel(&line, diag);
        }

        try self.processLine(&line, diag);
    }

    // make sure exported symbols are defined
    // make sure external symbols are used
    // resolve branches within file
    // remove exhausted symbols
}

fn processLine(self: *Self, line: *Tokenizer, diag: *Diagnostic) !void {
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
                .symbolTableIndex = symbolIndex,
                .offset = section.buffer.items.len,
            });
        }

        section.buffer.appendSlice(uintAsU8Slice(u32, inst.encoding));
        if (inst.extension) |extension| {
            section.buffer.appendSlice(uintAsU8Slice(u32, extension));
        }
    }
}

fn processLabel(self: *Self, line: *Tokenizer, diag: *Diagnostic) !void {
    var section: CodeSection = self.currSection orelse {
        diag.msg("section type not specified\n", .{});
        return error.ParseError;
    };

    const label = line.next() orelse return;
    if (!(parsing.tokenIsLabel(label))) {
        diag.msg("expected label\n", .{});
        return error.ParseError;
    }

    _ = parsing.expectOperator(":", line, diag);

    const symbolIndex = self.addLabel(label) catch |err| switch (err) {
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

    const directive = directiveMap.get(token) orelse {
        diag.msg("expected directive\n", .{});
        return error.ParseError;
    };

    switch (directive) {
        Directive.data => self.currSection = &self.dataSection,
        Directive.text => self.currSection = &self.textSection,
        Directive.bss => try self.bssDirective(&line, diag),
        Directive.@"align" => try self.alignDirective(&line, diag),
        Directive.@"export" => try self.exportDirective(&line, diag),
        // Directive.@"extern" => try self.exportDirective(&line, diag),
        Directive.word => _ = try self.dataDirective(u32, 0, &line, diag),
        Directive.half => _ = try self.dataDirective(u16, 0, &line, diag),
        Directive.byte => _ = try self.dataDirective(u8, 0, &line, diag),
        Directive.string => _ = try self.stringDirective(&line, diag),
        else => unreachable,
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
            error.ValueNotEncodable => try diag.msg("value is too large", .{}),
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
            error.ValueNotEncodable => try diag.msg("value is too large", .{}),
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

fn dataDirective(self: *Self, comptime T: type, depth: u1, line: *Tokenizer, diag: *Diagnostic) !usize {
    const numBytes = comptime switch (@typeInfo(T)) {
        .Int => |int| blk: {
            if (int.signedness == .signed) @compileError("T must be u8, u16, or u32");
            if (int.bits != 8 and int.bits != 16 and int.bits != 32) {
                @compileError("T must be u8, u16, or u32");
            }
            break :blk int.bits / 8;
        },
        else => @compileError("T must be u8, u16, or u32"),
    };

    // Positive values must be less than this value to be representable in `numBytes`
    const posMax: u32 = comptime std.math.maxInt(T);
    // Negated values must be greater than this value to be representable in `numBytes`
    const negMin: u32 = comptime (1 << 31) | (~posMax >> 1);

    var section: CodeSection = self.currSection orelse {
        diag.msg("section type not specified\n", .{});
        return error.ParseError;
    };

    if (parsing.optionalOperator("*", line) == '*') {
        // Save for error messages
        const asteriskLinePos = line.tokenStart;

        if (depth == 1) {
            diag.msg("implicit array lengths cannot be nested\n", .{});
            return error.ParseError;
        }
        _ = try parsing.expectOperator(".", line);

        // Reserve space to write size of following data
        section.buffer.append(uintAsU8Slice(@as(T, 0)));

        const token = line.next();
        const directive = directiveMap.get(token) orelse {
            diag.msg("expected directive\n", .{});
            return error.ParseError;
        };

        var arraySize: usize = undefined;
        switch (directive) {
            Directive.word => arraySize = try self.dataDirective(u32, 1, &line, diag),
            Directive.half => arraySize = try self.dataDirective(u16, 1, &line, diag),
            Directive.byte => arraySize = try self.dataDirective(u8, 1, &line, diag),
            Directive.string => arraySize = try self.stringDirective(&line, diag),
            else => {
                diag.msg("expected 'word', 'half', 'byte', or 'string'\n", .{});
                return error.ParseError;
            },
        }

        if (arraySize > posMax) {
            line.tokenStart = asteriskLinePos;
            diag.msg("array length is out of range", .{});
            return error.ParseError;
        }

        return 0;
    }

    var bytesAdded: usize = 0;

    while (line.next()) |token| {
        const negated = if (parsing.optionalOperator("-", line) == '-') true else false;

        var val: u32 = parsing.parseInteger(token) catch |err| {
            switch (err) {
                error.Unexpected => try diag.msg("expected value\n", .{}),
                error.ValueNotEncodable => diag.msg("value is too large\n", .{}),
            }
            return error.ParseError;
        };

        if (negated) val = ~val + 1;

        if ((negated and val < negMin) or val > posMax) {
            diag.msg("value is out of range\n", .{});
            return error.ParseError;
        }

        section.buffer.appendSlice(uintAsU8Slice(@as(T, @truncate(val))));
        bytesAdded += numBytes;

        if (parsing.optionalOperator(",")) |c| switch (c) {
            ',' => {},
            '\n' => return bytesAdded,
            else => unreachable,
        } else {
            diag.msg("expected ',' or EOL\n", .{});
            return error.ParseError;
        }
    }

    diag.msg("expected value\n", .{});
    return error.ParseError;
}

fn stringDirective(self: *Self, line: *Tokenizer, diag: *Diagnostic) !usize {
    _ = self;
    _ = line;
    _ = diag;
    return 0;
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
    var newSymbol: [*]u8 = self.allocator.alloc(str.len);
    @memcpy(newSymbol[0..str.len], str);
    try self.symbolTable.append(.{ .refs = 1, .sym = newSymbol[0..str.len] });
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
    var newSymbol: [*]u8 = self.allocator.alloc(str.len);
    @memcpy(newSymbol[0..str.len], str);
    try self.symbolTable.append(.{ .refs = 1, .sym = newSymbol[0..str.len] });
    return self.symbolTable.items.len - 1;
}

/// Cast an unsigned integer to a slice for appending to a file buffer.
pub inline fn uintAsU8Slice(comptime T: type, encoding: u32) []const u8 {
    const bytes = comptime switch (@typeInfo(T)) {
        .Int => |int| blk: {
            if (int.signedness == .signed) @compileError("int cannot be signed");
            if (int.bits % 8 != 0) @compileError("int width must be a byte multiple");
            break :blk int.bits / 8;
        },
        else => @compileError("integer type required"),
    };

    const littleEndian = std.mem.nativeToLittle(T, encoding);
    return @as(*const [bytes]u8, @ptrCast(&littleEndian)).*[0..];
}
