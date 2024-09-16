const std = @import("std");
const datetime = @import("datetime");

pub fn main() !void {
    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();

    const now = try datetime.DateTime.fromTimestamp(.{ .ns = std.time.nanoTimestamp() }, .{});

    try now.formatISO8601(stdout, .{ .format = .extended, .resolution = .ns });
    try stdout.print("\n", .{});
    try bw.flush();
}
