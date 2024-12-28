const std = @import("std");

var pathBuffer: [1024]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&pathBuffer);
pub var path = std.ArrayList(u8).init(fba.allocator());

pub var lineNumber: u32 = 0;
pub var columnNumber: u32 = 0;
