# DateTime.zig

Time Zone awared Date Time.

## Usage

```shell
zig fetch --save=datetime git+https://github.com/ymd-h/datetime.zig
```

```zig
const std = @import("std");
const datetime = @import("datetime");

pub fn main(){
    // Create from Timestamp
    const dt = DateTime.fromTimestamp(.{ .s = std.time.timestamp() }, .{});
    std.debug.print(
        "{}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{}.{d:0>3}{d:0>3}{d:0>3}",
        .{ dt.year, dt.month, dt.date,
           dt.hour, dt.minute, dt.second,
           dt.ms, dt.us, dt.ns });

    // Parse ISO8601 date string
    const dt2 = try DateTime.parse("2024-09-15T11:15:23.987+09:00");

    // Compare DateTime
    _ = try dt.earlierThan(dt2);
    _ = try dt.laterThan(dt2);
    _ = try dt.equal(dt2);
}
```
