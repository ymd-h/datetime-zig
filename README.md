# DateTime.zig

Time Zone awared Date Time.

> [!WARNING]
> This project is still under development.


## 1. Usage

### 1.1 Add dependency


```shell
zig fetch --save git+https://github.com/ymd-h/datetime.zig#v0.0.4
```


In build.zig

```zig
pub fn build(b: *b.std.Build) !void {
    const exe = b.addExecutable(
        // (omit)
    );

    const datetime = b.dependency("datetime-zig", .{ .target = .target, .optimize = .optimize });
    exe.root_module.addImport("datetime", datetime.module("datetime"));
}
```



### 1.2 Code


```zig
const std = @import("std");
const datetime = @import("datetime");
const DateTime = datetime.DateTime;

pub fn main(){
    // Create from Timestamp and TimeZone
    const dt = DateTime.fromTimestamp(.{ .s = std.time.timestamp() }, .{});
    _ = try DateTime.fromTimestamp(.{ .ms = std.time.milliTimestamp() }, .{});
    _ = try DateTime.fromTimestamp(.{ .us = std.time.microTimestamp() }, .{});
    _ = try DateTime.fromTimestamp(.{ .ns = std.time.nanoTimestamp() }, .{});
    _ = try DateTime.fromTimestamp(.{ .s = std.time.timestamp() }, .{ .hour = 2, .minute = 30 });

    // Parse ISO8601 date string
    const dt2 = try DateTime.parse("2024-09-15T11:15:23.987+09:00");

    // Format ISO8601
    var w = std.io.bufferedWriter(std.iogetStdOut().writer());
    const stdout = bw.writer();
    try dt.formatISO8601(stdout, .{ .format = .extended, .resolution = .ms });
    try stdout.print("\n", .{});
    try bw.flush();

    // Custom Format
    try dt.formatCustom(stdout, "%Y/%m/%d %H:%M:%S.%f %:z\n");


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


Leap second (`.second = 60`) is accepted and can be compared,
however, it will be ignored when exporting to UNIX timestamp.


## 2. Features
- Construct `DateTime` from `Timestamp` and `TimeZone`
- Get timestamp with resolution of second, milli second, micro second, and nano second
- Change `TimeZone`
- Parse ISO8601 basic and extended format
- Write ISO8601 basic and extended format, or custom format
- Compare two `DateTime`
- Sort `DateTime` slice
- `floor()` and `ceil()` with resolution of century, year, hour, date, hour, minute, second, milli second, micro second, and nano second.
