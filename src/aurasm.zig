const std = @import("std");
const stderr = std.io.getStdErr();
var stderrBuffered = std.io.bufferedWriter(stderr.writer());
var stderrWriter = stderrBuffered.writer();

const Tokenizer = @import("tokenizer.zig");
const Instruction = @import("encode_instruction.zig").Instruction;
const encodeInstruction = @import("encode_instruction.zig").encodeInstruction;
const ParseError = @import("parsing.zig").ParseError;

const Allocator = std.mem.Allocator;

const display = @import("error_message.zig").displayTokenInLine;



pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();

    const fileName = args.next() orelse {
        std.debug.print("no file\n", .{});
        return;
    };

    var file = try std.fs.cwd().openFile(fileName, .{});
    defer file.close();

    var buffered = std.io.bufferedReader(file.reader());
    var reader = buffered.reader();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var lineBuffer = try std.BoundedArray(u8, 1024).init(0);
    var err = ParseError.init(allocator);
    defer ParseError.deinit();

    const sections = struct {
        text: ?*CodeSection,
        data: ?*CodeSection,
    };

    var lineNumber: usize = 1;
    var activeSection: ?*CodeSection = null;

    while (reader.streamUntilDelimiter(lineBuffer.writer(), '\n', null)) : (lineNumber += 1) {
        defer lineBuffer.resize(0) catch unreachable;
        var line: Tokenizer = Tokenizer.init(lineBuffer.slice());

        _ = line.next() orelse continue;
        line.putBack();

        const inst = encodeInstruction(&line, &err) catch |e| switch (e) {
            error.ParseError => {
                std.debug.print("{s}", .{err.text.items});
                try display(&line);
                continue;
            },
            else => return e,
        };

        std.debug.print("0x{X:>8}: {s}\n", .{ inst.encoding, lineBuffer.slice() });
        if (inst.extension) |ext| {
            std.debug.print("0x{X:>8}:\n", .{ext});
        }
    } else |e| {
        std.debug.print("error: {}\n", .{e});
    }
}
