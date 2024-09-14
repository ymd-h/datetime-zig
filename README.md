# DateTime.zig

Time Zone awared Date Time.

## Usage

```zig
const std = @import("std");
const datetime = @import("datetime.zig");

pub fn main(){
    const dt = DateTime.fromTimestamp(.{ .s = std.time.timestamp() }, .{});
    std.debug.print(
        "{}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{}.{d:0>3}{d:0>3}{d:0>3}",
        .{ dt.year, dt.month, dt.date,
           dt.hour, dt.minute, dt.second,
           dt.ms, dt.us, dt.ns });
}
```
