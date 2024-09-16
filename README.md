# DateTime.zig

Time Zone awared Date Time.

## 1. Usage

### 1.1 Add dependency


```shell
zig fetch --save=datetime git+https://github.com/ymd-h/datetime.zig
```


In build.zig

```zig
pub fn build(b: *b.std.Build) !void {
    // (omit)
    const exe = // your project executable

    const datetime = b.dependency("datetime", .{ .target = .target, .optimize = .optimize });

    exe.addModule("datetime", datetime.module("datetime"));
    exe.linkLibrary(datetime.artifact("datetime"));
}
```



### 1.2 Code


```zig
const std = @import("std");
const datetime = @import("datetime");

pub fn main(){
    // Create from Timestamp and TimeZone
    const dt = DateTime.fromTimestamp(.{ .s = std.time.timestamp() }, .{});
    std.debug.print(
        "{}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{}.{d:0>3}{d:0>3}{d:0>3}",
        .{ dt.year, dt.month, dt.date,
           dt.hour, dt.minute, dt.second,
           dt.ms, dt.us, dt.ns });
    _ = try DateTime.fromTimestamp(.{ .ms = std.time.milliTimestamp() }, .{});
    _ = try DateTime.fromTimestamp(.{ .us = std.time.microTimestamp() }, .{});
    _ = try DateTime.fromTimestamp(.{ .ns = std.time.nanoTimestamp() }, .{});
    _ = try DateTime.fromTimestamp(.{ .s = std.time.timestamp() }, .{ .hour = 2, .minute = 30 });

    // Parse ISO8601 date string
    const dt2 = try DateTime.parse("2024-09-15T11:15:23.987+09:00");

    // Compare DateTime
    _ = try dt.earlierThan(dt2);
    _ = try dt.laterThan(dt2);
    _ = try dt.equal(dt2);


    // Get Timestamp (elapsed time from 1970-01-01T00:00:00Z)
    _ = try dt.getTimestamp(); // i64
    _ = try dt.getMilliTimestamp(); // i64
    _ = try dt.getMicroTimestamp(); // i64
    _ = try dt.getNanoTimestamp(); // i128


    // Get day of week
    _ = try dt.dayOfWeek(); // enum { .Sunday, .Monday, .Tuesday, .Wednesday, .Thursday, .Friday, .Saturday }


    // Sort
    var dates = [_]Date{ dt, dt2 };
    try DateTime.sort(&dates, .asc);
    try DateTime.sort(&dates, .desc);
}
```

Since fields can be changed from outside freely,
methods validate its values and fail unless it is valid.
