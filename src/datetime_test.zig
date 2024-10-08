//! Test for datetime.zig

const std = @import("std");
const testing = std.testing;

// Public API
const mod = @import("datetime.zig");
const DateTime = mod.DateTime;
const TimeZone = mod.TimeZone;
const Timestamp = mod.Timestamp;
const Duration = mod.Duration;
const countLeapYear = mod.countLeapYear;
const getDaysInMonth = mod.getDaysInMonth;

test "countLeapYear" {
    try testing.expectEqual(1, countLeapYear(2000, 2001));
    try testing.expectEqual(0, countLeapYear(2001, 2002));
    try testing.expectEqual(2, countLeapYear(2000, 2005));
    try testing.expectEqual(0, countLeapYear(1900, 1901));
    try testing.expectError(error.InvalidRange, countLeapYear(1900, 1900));
}

test "getDaysInMonth" {
    try testing.expectEqual(31, getDaysInMonth(false, 1));
    try testing.expectEqual(28, getDaysInMonth(false, 2));
    try testing.expectEqual(31, getDaysInMonth(false, 3));
    try testing.expectEqual(30, getDaysInMonth(false, 4));
    try testing.expectEqual(31, getDaysInMonth(false, 5));
    try testing.expectEqual(30, getDaysInMonth(false, 6));
    try testing.expectEqual(31, getDaysInMonth(false, 7));
    try testing.expectEqual(31, getDaysInMonth(false, 8));
    try testing.expectEqual(30, getDaysInMonth(false, 9));
    try testing.expectEqual(31, getDaysInMonth(false, 10));
    try testing.expectEqual(30, getDaysInMonth(false, 11));
    try testing.expectEqual(31, getDaysInMonth(false, 12));
    try testing.expectEqual(31, getDaysInMonth(true, 1));
    try testing.expectEqual(29, getDaysInMonth(true, 2));
    try testing.expectEqual(31, getDaysInMonth(true, 3));
    try testing.expectEqual(30, getDaysInMonth(true, 4));
    try testing.expectEqual(31, getDaysInMonth(true, 5));
    try testing.expectEqual(30, getDaysInMonth(true, 6));
    try testing.expectEqual(31, getDaysInMonth(true, 7));
    try testing.expectEqual(31, getDaysInMonth(true, 8));
    try testing.expectEqual(30, getDaysInMonth(true, 9));
    try testing.expectEqual(31, getDaysInMonth(true, 10));
    try testing.expectEqual(30, getDaysInMonth(true, 11));
    try testing.expectEqual(31, getDaysInMonth(true, 12));
    try testing.expectError(error.InvalidMonth, getDaysInMonth(true, 0));
    try testing.expectError(error.InvalidMonth, getDaysInMonth(true, 13));
}

test "Timestamp.nanoseconds" {
    try testing.expectEqual(0, (Timestamp{ .s = 0 }).nanoseconds());
    try testing.expectEqual(1_000_000_000, (Timestamp{ .s = 1 }).nanoseconds());
    try testing.expectEqual(1_000_000, (Timestamp{ .ms = 1 }).nanoseconds());
    try testing.expectEqual(1_000, (Timestamp{ .us = 1 }).nanoseconds());
    try testing.expectEqual(1, (Timestamp{ .ns = 1 }).nanoseconds());
}

test "Timestamp.equal" {
    try testing.expect((Timestamp{ .s = 0 }).equal(Timestamp{ .ms = 0 }));
    try testing.expect((Timestamp{ .s = 1 }).equal(Timestamp{ .ms = 1_000 }));
    try testing.expect((Timestamp{ .s = 0 }).equal(Timestamp{ .ms = 0 }));
    try testing.expect((Timestamp{ .ns = 1_000_000 }).equal(Timestamp{ .ms = 1 }));
    try testing.expect(!(Timestamp{ .s = 0 }).equal(Timestamp{ .s = 1 }));
    try testing.expect(!(Timestamp{ .ns = 1 }).equal(Timestamp{ .ms = 1 }));
}

test "TimeZone" {
    try testing.expectEqual(9 * 3600, (TimeZone{ .hour = 9 }).seconds());
    try testing.expectEqual(12 * 3600, (TimeZone{ .hour = 12 }).seconds());
    try testing.expectEqual(-12 * 3600, (TimeZone{ .hour = -12 }).seconds());
    try testing.expectEqual(60 * 30, (TimeZone{ .minute = 30 }).seconds());
    try testing.expectEqual(60 * 45, (TimeZone{ .minute = 45 }).seconds());
}

test "TimeZone.validate" {
    try testing.expectError(error.InvalidTimeZone, (TimeZone{ .hour = 5, .minute = -15 }).validate());
}

test "DateTime allocate" {
    var dt = try std.testing.allocator.create(DateTime);
    defer std.testing.allocator.destroy(dt);
    dt.* = .{};

    try testing.expectEqualDeep(DateTime{}, dt.*);

    try dt.parseInto("2022-01-31T12:45:09.123-08:15");
    try testing.expectEqualDeep(
        DateTime{ .year = 2022, .month = 1, .date = 31, .hour = 12, .minute = 45, .second = 9, .ms = 123, .tz = .{ .hour = -8, .minute = -15 } },
        dt.*,
    );
}

test "DateTime.validate" {
    try (DateTime{}).validate();
    try (DateTime{ .year = 1 }).validate();
    try (DateTime{ .year = 3000 }).validate();
    try (DateTime{ .year = 4000 }).validate();
    try (DateTime{ .month = 1 }).validate();
    try (DateTime{ .month = 12 }).validate();
    try (DateTime{ .year = 2000, .month = 2, .date = 29 }).validate();
    try testing.expectError(error.InvalidYear, (DateTime{ .year = 0 }).validate());
    try testing.expectError(error.InvalidMonth, (DateTime{ .month = 0 }).validate());
    try testing.expectError(error.InvalidMonth, (DateTime{ .month = 13 }).validate());
    try testing.expectError(error.InvalidDate, (DateTime{ .date = 0 }).validate());
    try testing.expectError(error.InvalidDate, (DateTime{ .year = 1900, .month = 2, .date = 29 }).validate());
    try testing.expectError(error.InvalidHour, (DateTime{ .hour = 24 }).validate());
    try testing.expectError(error.InvalidMinute, (DateTime{ .minute = 60 }).validate());
    try testing.expectError(error.InvalidSecond, (DateTime{ .second = 61 }).validate());
    try testing.expectError(error.InvalidMilliSecond, (DateTime{ .ms = 1000 }).validate());
    try testing.expectError(error.InvalidMicroSecond, (DateTime{ .us = 1000 }).validate());
    try testing.expectError(error.InvalidNanoSecond, (DateTime{ .ns = 1000 }).validate());
}

test "DataTime.fromTimestamp" {
    try testing.expectEqualDeep(DateTime{}, DateTime.fromTimestamp(.{ .s = 0 }, .{}));
    try testing.expectEqualDeep(DateTime{ .year = 2024, .month = 9, .date = 13, .hour = 12, .minute = 53, .second = 55, .ms = 40, .tz = .{ .hour = 9 } }, DateTime.fromTimestamp(.{ .ms = 1726199635040 }, .{ .hour = 9 }));
    const oldest = try (DateTime{ .year = 1 }).getTimestamp();
    try testing.expectError(error.TooOld, DateTime.fromTimestamp(.{ .s = oldest - 1 }, .{}));
}

test "DateTime.getTimestamp" {
    try testing.expectEqual(0, (DateTime{}).getTimestamp());
    try testing.expectEqual(0, (DateTime{}).getMilliTimestamp());
    try testing.expectEqual(0, (DateTime{}).getMicroTimestamp());
    try testing.expectEqual(0, (DateTime{}).getNanoTimestamp());
    try testing.expectEqual(1, (DateTime{ .second = 1 }).getTimestamp());
    try testing.expectEqual(60, (DateTime{ .minute = 1 }).getTimestamp());
    try testing.expectEqual(3600, (DateTime{ .hour = 1 }).getTimestamp());
    try testing.expectEqual(86400, (DateTime{ .date = 2 }).getTimestamp());
    try testing.expectEqual(
        978274799_999_999_999,
        (DateTime{ .year = 2000, .month = 12, .date = 31, .hour = 23, .minute = 59, .second = 59, .ms = 999, .us = 999, .ns = 999, .tz = .{ .hour = 9 } }).getNanoTimestamp(),
    );
}

test "DateTime consistensy" {
    const s = std.time.timestamp();
    try testing.expectEqual(
        s,
        (try DateTime.fromTimestamp(.{ .s = s }, .{})).getTimestamp(),
    );

    const ms = std.time.milliTimestamp();
    try testing.expectEqual(
        ms,
        (try DateTime.fromTimestamp(.{ .ms = ms }, .{})).getMilliTimestamp(),
    );

    const tz: TimeZone = .{ .hour = 12, .minute = 30 };
    const dt: DateTime = .{
        .year = 3000,
        .month = 12,
        .date = 31,
        .hour = 23,
        .minute = 59,
        .second = 59,
        .ms = 999,
        .us = 999,
        .ns = 999,
        .tz = tz,
    };
    try testing.expectEqualDeep(
        dt,
        DateTime.fromTimestamp(.{ .ns = (try dt.getNanoTimestamp()) }, tz),
    );

    const dt2 = DateTime{ .month = 10, .date = 31 };
    try testing.expectEqualDeep(
        dt2,
        DateTime.fromTimestamp(.{ .ns = (try dt2.getNanoTimestamp()) }, .{}),
    );
}

test "DateTime.parse" {
    try testing.expectEqual(DateTime{ .year = 2024 }, DateTime.parse("2024"));
    try testing.expectError(
        error.InvalidString,
        DateTime.parse("202409"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14 },
        DateTime.parse("20240914"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 21, .minute = 25 },
        DateTime.parse("20240914T2125"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 21, .minute = 25, .second = 9 },
        DateTime.parse("20240914T212509"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 21, .minute = 25, .second = 9 },
        DateTime.parse("20240914T212509Z"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 21, .minute = 25, .second = 9, .tz = .{ .hour = -7 } },
        DateTime.parse("20240914T212509-07"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 21, .minute = 25, .second = 9, .tz = .{ .hour = -7, .minute = -45 } },
        DateTime.parse("20240914T212509-0745"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 21, .minute = 25, .second = 9, .ms = 124 },
        DateTime.parse("20240914T212509.124"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 21, .minute = 25, .second = 9, .ms = 124, .us = 24 },
        DateTime.parse("20240914T212509.124024"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 21, .minute = 25, .second = 9, .ms = 124, .us = 24, .ns = 999 },
        DateTime.parse("20240914T212509.124024999"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 21, .minute = 25, .second = 9, .ms = 124, .us = 24, .ns = 999 },
        DateTime.parse("20240914T212509.124024999Z"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 21, .minute = 25, .second = 9, .ms = 124, .us = 24, .ns = 999, .tz = .{ .hour = 1 } },
        DateTime.parse("20240914T212509.124024999+01"),
    );

    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9 },
        DateTime.parse("2024-09"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14 },
        DateTime.parse("2024-09-14"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 23, .minute = 14 },
        DateTime.parse("2024-09-14T23:14"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 23, .minute = 14, .second = 22 },
        DateTime.parse("2024-09-14T23:14:22"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 23, .minute = 14, .second = 22 },
        DateTime.parse("2024-09-14T23:14:22Z"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 23, .minute = 14, .second = 22, .tz = .{ .hour = 9 } },
        DateTime.parse("2024-09-14T23:14:22+09"),
    );
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 23, .minute = 14, .second = 22, .tz = .{ .hour = 9, .minute = 30 } },
        DateTime.parse("2024-09-14T23:14:22+09:30"),
    );

    try testing.expectError(error.InvalidString, DateTime.parse("2024/09/13"));
}

test "DateTime.parseInto" {
    var dt: DateTime = .{ .year = 2000, .date = 9 };
    try dt.parseInto("2024-09-14T23:14:22+09");
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 23, .minute = 14, .second = 22, .tz = .{ .hour = 9 } },
        dt,
    );

    try testing.expectError(error.InvalidString, dt.parseInto("Invalid String"));
    try testing.expectEqual(
        DateTime{ .year = 2024, .month = 9, .date = 14, .hour = 23, .minute = 14, .second = 22, .tz = .{ .hour = 9 } },
        dt,
    );
}

test "DateTime compare" {
    try testing.expect(
        try (DateTime{ .year = 2024 }).earlierThan(DateTime{ .year = 2025 }),
    );
    try testing.expect(
        try (DateTime{ .year = 2024, .month = 4 })
            .earlierThan(DateTime{ .year = 2024, .month = 5 }),
    );
    try testing.expect(
        try (DateTime{ .year = 2024, .month = 4, .date = 12 })
            .earlierThan(DateTime{ .year = 2024, .month = 4, .date = 13 }),
    );
    try testing.expect(
        try (DateTime{ .year = 2024, .month = 4, .date = 12 })
            .earlierThan(DateTime{ .year = 2024, .month = 4, .date = 12, .tz = .{ .hour = -3 } }),
    );

    try testing.expect(
        try (DateTime{ .year = 2024 }).laterThan(DateTime{ .year = 2023 }),
    );
    try testing.expect(
        try (DateTime{ .year = 2024, .month = 4 })
            .laterThan(DateTime{ .year = 2024, .month = 3 }),
    );
    try testing.expect(
        try (DateTime{ .year = 2024, .month = 4, .date = 12 })
            .laterThan(DateTime{ .year = 2024, .month = 4, .date = 11 }),
    );
    try testing.expect(
        try (DateTime{ .year = 2024, .month = 9, .date = 15 })
            .laterThan(DateTime{ .year = 2024, .month = 9, .date = 15, .tz = .{ .hour = 9 } }),
    );

    try testing.expect(
        try (DateTime{ .year = 2024, .month = 4, .date = 12 })
            .equal(DateTime{ .year = 2024, .month = 4, .date = 12 }),
    );
    try testing.expect(
        try (DateTime{ .year = 2024, .month = 4, .date = 12 })
            .equal(DateTime{ .year = 2024, .month = 4, .date = 12, .hour = 9, .tz = .{ .hour = 9 } }),
    );
}

test "DateTime.dayOfWeek" {
    try testing.expectEqual(
        .Monday,
        (DateTime{ .year = 1, .month = 1, .date = 1 }).dayOfWeek(),
    );
    try testing.expectEqual(
        .Sunday,
        (DateTime{ .year = 2024, .month = 9, .date = 15 }).dayOfWeek(),
    );
}

test "DateTime.dayOfYear" {
    try testing.expectEqual(1, (DateTime{}).dayOfYear());
    try testing.expectEqual(
        365,
        (DateTime{ .year = 1999, .month = 12, .date = 31 }).dayOfYear(),
    );
    try testing.expectEqual(
        366,
        (DateTime{ .year = 2000, .month = 12, .date = 31 }).dayOfYear(),
    );
}

test "DateTime.sort" {
    var dates = [_]DateTime{
        DateTime{ .year = 2024 },
        DateTime{ .year = 2023 },
        DateTime{ .year = 2024, .month = 5 },
        DateTime{ .year = 2024, .month = 4, .date = 30, .hour = 23, .tz = .{ .hour = -9 } },
    };

    try DateTime.sort(&dates, .asc);
    try testing.expectEqualSlices(
        DateTime,
        &([_]DateTime{
            DateTime{ .year = 2023 },
            DateTime{ .year = 2024 },
            DateTime{ .year = 2024, .month = 5 },
            DateTime{ .year = 2024, .month = 4, .date = 30, .hour = 23, .tz = .{ .hour = -9 } },
        }),
        &dates,
    );

    try DateTime.sort(&dates, .desc);
    try testing.expectEqualSlices(
        DateTime,
        &([_]DateTime{
            DateTime{ .year = 2024, .month = 4, .date = 30, .hour = 23, .tz = .{ .hour = -9 } },
            DateTime{ .year = 2024, .month = 5 },
            DateTime{ .year = 2024 },
            DateTime{ .year = 2023 },
        }),
        &dates,
    );
}

test "DateTime.changeTimeZone" {
    var dt = DateTime{ .year = 2024, .tz = .{ .hour = -9 } };
    try dt.changeTimeZone(.{});
    try testing.expectEqualDeep(DateTime{ .year = 2024, .hour = 9 }, dt);
}

test "DateTime.format" {
    var L = std.ArrayList(u8).init(testing.allocator);
    defer L.deinit();

    const dt = DateTime{ .year = 1988, .month = 5, .date = 22, .tz = .{ .hour = 9 } };
    try dt.formatISO8601(L.writer(), .{ .format = .extended, .resolution = .ms });

    try testing.expectEqualSlices(u8, "1988-05-22T00:00:00.000+09:00", L.items);
}

test "DateTime.formatCustom" {
    var L = std.ArrayList(u8).init(testing.allocator);
    defer L.deinit();

    const dt = try DateTime.parse("1234-05-06T07:08:09.123456789+12:30");

    try dt.formatCustom(L.writer(), "%Y/%m/%d");
    try testing.expectEqualSlices(u8, "1234/05/06", L.items);

    L.clearRetainingCapacity();
    try dt.formatCustom(L.writer(), "%H:%M:%S");
    try testing.expectEqualSlices(u8, "07:08:09", L.items);

    L.clearRetainingCapacity();
    try dt.formatCustom(L.writer(), "%f");
    try testing.expectEqualSlices(u8, "123456", L.items);

    L.clearRetainingCapacity();
    try dt.formatCustom(L.writer(), "%z%%%:z");
    try testing.expectEqualSlices(u8, "+1230%+12:30", L.items);

    L.clearRetainingCapacity();
    try dt.formatCustom(L.writer(), "Year: %Y, Month: %m, Date: %d");
    try testing.expectEqualSlices(u8, "Year: 1234, Month: 05, Date: 06", L.items);
}

test "DateTime leap second" {
    const dt = DateTime{ .second = 59 };
    const dt_t = DateTime{ .second = 59, .hour = 9, .tz = .{ .hour = 9 } };
    const dt_l = DateTime{ .second = 60 };
    try dt_l.validate();
    try testing.expect(try dt.equal(dt_t));

    try testing.expect(try dt.earlierThan(dt_l));
    try testing.expect(try dt_t.earlierThan(dt_l));
    try testing.expect(!try dt.equal(dt_l));
    try testing.expect(!try dt_t.equal(dt_l));
    try testing.expectEqual(dt.getTimestamp(), dt_l.getTimestamp());
}

test "Duration" {
    try testing.expectEqual(
        100_000_000_000,
        (Duration{ .ns = 100_000_000_000 }).nanoseconds(),
    );
    try testing.expectEqual(
        100_000_000_000,
        (Duration{ .us = 100_000_000 }).nanoseconds(),
    );
    try testing.expectEqual(
        100_000_000_000,
        (Duration{ .ms = 100_000 }).nanoseconds(),
    );
    try testing.expectEqual(
        100_000_000_000,
        (Duration{ .seconds = 100 }).nanoseconds(),
    );
    try testing.expectEqual(
        24 * 60 * 60 * 1_000_000_000,
        (Duration{ .days = 1 }).nanoseconds(),
    );

    _ = (Duration{ .days = std.math.maxInt(i32) }).nanoseconds();
    _ = (Duration{ .hours = std.math.maxInt(i64) }).nanoseconds();
}

test "DateTime.addDuration" {
    var dt = DateTime{};

    try dt.addDuration(.{ .days = 3 });
    try testing.expectEqualDeep(DateTime{ .date = 4 }, dt);

    try dt.addDuration(.{ .ns = -300 });
    try testing.expectEqualDeep(DateTime{ .date = 3, .hour = 23, .minute = 59, .second = 59, .ms = 999, .us = 999, .ns = 700 }, dt);
}

test "DateTime.floor" {
    var dt = DateTime{ .hour = 3, .minute = 24, .ms = 200 };
    try dt.floor(.hour);
    try testing.expectEqualDeep(DateTime{ .hour = 3 }, dt);

    dt = DateTime{ .us = 150, .ns = 120 };
    try dt.floor(.ns);
    try testing.expectEqualDeep(DateTime{ .us = 150, .ns = 120 }, dt);

    dt = DateTime{ .year = 1507 };
    try dt.floor(.century);
    try testing.expectEqualDeep(DateTime{ .year = 1501 }, dt);

    try dt.floor(.century);
    try testing.expectEqualDeep(DateTime{ .year = 1501 }, dt);

    dt = DateTime{ .month = 2, .date = 15 };
    try dt.floor(.month);
    try testing.expectEqualDeep(DateTime{ .month = 2 }, dt);

    dt = DateTime{ .hour = 5, .tz = .{ .hour = 8 } };
    try dt.floor(.date);
    try testing.expectEqualDeep(DateTime{ .tz = .{ .hour = 8 } }, dt);

    dt = DateTime{ .minute = 34, .ms = 22 };
    try dt.floor(.hour);
    try testing.expectEqualDeep(DateTime{}, dt);

    dt = DateTime{ .year = 2022, .second = 54, .ms = 199 };
    try dt.floor(.minute);
    try testing.expectEqualDeep(DateTime{ .year = 2022 }, dt);

    dt = DateTime{ .year = 2022, .second = 54, .ms = 199 };
    try dt.floor(.second);
    try testing.expectEqualDeep(DateTime{ .year = 2022, .second = 54 }, dt);

    dt = DateTime{ .year = 2022, .second = 54, .ms = 199, .us = 22 };
    try dt.floor(.ms);
    try testing.expectEqualDeep(DateTime{ .year = 2022, .second = 54, .ms = 199 }, dt);

    dt = DateTime{ .year = 2022, .second = 54, .ms = 199, .us = 22, .ns = 32 };
    try dt.floor(.us);
    try testing.expectEqualDeep(DateTime{ .year = 2022, .second = 54, .ms = 199, .us = 22 }, dt);

    dt = DateTime{ .year = 2022, .second = 54, .ms = 199, .us = 22, .ns = 32 };
    try dt.floor(.ns);
    try testing.expectEqualDeep(DateTime{ .year = 2022, .second = 54, .ms = 199, .us = 22, .ns = 32 }, dt);
}

test "DateTime.ceil" {
    var dt = DateTime{ .hour = 3, .minute = 23, .ms = 300 };
    try dt.ceil(.century);
    try testing.expectEqualDeep(DateTime{ .year = 2001 }, dt);

    dt = DateTime{ .hour = 3, .minute = 23, .ms = 300 };
    try dt.ceil(.year);
    try testing.expectEqualDeep(DateTime{ .year = 1971 }, dt);

    dt = DateTime{ .hour = 3, .minute = 23, .ms = 300 };
    try dt.ceil(.month);
    try testing.expectEqualDeep(DateTime{ .month = 2 }, dt);

    dt = DateTime{ .hour = 3, .minute = 23, .ms = 300 };
    try dt.ceil(.date);
    try testing.expectEqualDeep(DateTime{ .date = 2 }, dt);

    dt = DateTime{ .hour = 3, .minute = 23, .ms = 300 };
    try dt.ceil(.hour);
    try testing.expectEqualDeep(DateTime{ .hour = 4 }, dt);

    dt = DateTime{ .hour = 3, .minute = 23, .ms = 300 };
    try dt.ceil(.minute);
    try testing.expectEqualDeep(DateTime{ .hour = 3, .minute = 24 }, dt);

    dt = DateTime{ .hour = 3, .minute = 23, .ms = 300, .tz = .{ .minute = -30 } };
    try dt.ceil(.second);
    try testing.expectEqualDeep(DateTime{ .hour = 3, .minute = 23, .second = 1, .tz = .{ .minute = -30 } }, dt);

    dt = DateTime{ .hour = 3, .minute = 23, .ms = 300, .us = 20 };
    try dt.ceil(.ms);
    try testing.expectEqualDeep(DateTime{ .hour = 3, .minute = 23, .ms = 301 }, dt);

    dt = DateTime{ .hour = 3, .minute = 23, .ms = 300, .us = 20, .ns = 1 };
    try dt.ceil(.us);
    try testing.expectEqualDeep(DateTime{ .hour = 3, .minute = 23, .ms = 300, .us = 21 }, dt);

    dt = DateTime{ .hour = 3, .minute = 23, .ms = 300 };
    try dt.ceil(.ns);
    try testing.expectEqualDeep(DateTime{ .hour = 3, .minute = 23, .ms = 300 }, dt);
}
