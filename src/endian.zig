const std = @import("std");

// fn encodingAsSlice(encoding: u32) []const u8 {
//     const littleEndian = std.mem.nativeToLittle(u64, encoding);
//     const array: *const [8]u8 = @ptrCast(&littleEndian);
//     return array.*[0..];
// }
fn encodingAsSlice(encoding: u32) []const u8 {
    const littleEndian = std.mem.nativeToLittle(u32, encoding);
    return @as(*const [4]u8, @ptrCast(&littleEndian)).*[0..];
}

pub fn main() !void {
    const uint: u32 = 0x44332211;
    for (encodingAsSlice(uint)) |byte| {
        std.debug.print("{X}\n", .{byte});
    }
}
