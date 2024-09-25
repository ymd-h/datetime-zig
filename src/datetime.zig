//! # datetime.zig
//!
//! datetime.zig provides timezone awared `DateTime`.
//!
//! `DateTime` struct has human readable fields like `year`, `month` etc,
//! and `tz` of `TimeZone`.
//!
//! ## Construct `DateTime`
//! `DateTime` can be constructed with several ways.
//!
//!  - Manual construction
//!    - Default fields are 1970-01-01 00:00:00Z
//!  - From `Timestamp` and `TimeZone` (aka. `DateTime.fromTimestamp()`)
//!  - Parse ISO8601 date time string (aka. `DateTime.parse()`)
//!    - Basic and extended formats are supported
//!    - Some format like quarter, number of weeks are not supported
//!
//! ## Compare `DateTime`
//! `DateTime` can be compared based on timestamp.
//!
//! However, leap second (`60s`) is an exception,
//! which is considered to be later than `59s`.
//!
//! - `DateTime.laterThan()`
//! - `DateTime.earlierThan()`
//! - `DateTime.equal()`
//! - `DateTime.sort()`
//!
//! ## Format `DateTime`
//! `DateTime` can format with ISO8601 or user defined custom format.
//! These methods take `std.io.Writer` like interface.
//!
//! - `DateTime.formatISO8601()`
//! - `DateTime.formatCustom()`
//!
//! ## Key differences from `std.time` and `std.time.epoch`
//! - Month is number (`u4`) instead of enum
//! - Negative timestamp (before `1970-01-01T00:00:00Z`) is supported

const std = @import("std");
const testing = std.testing;

test "Public API test" {
    _ = @import("datetime_test.zig");
}

const s_per_year = std.time.s_per_day * 365;
const s_per_leap_year = std.time.s_per_day * 366;

/// Day of the Week
pub const DayOfWeek = enum(u4) {
    Sunday,
    Monday,
    Tuesday,
    Wednesday,
    Thursday,
    Friday,
    Saturday,
};

/// Parse string `s` to integer with specified type `T`
/// We assume string is ascii encoded digit with `n` length.
/// This will fail with `error.InvalidString`,
/// when `s` doesn't have `n` length or contains non digit letters.
fn parseInt(comptime T: type, s: []const u8, n: usize) !T {
    const zero: u8 = '0';
    const nine: u8 = '9';

    try mustHave(s, n);

    var d: T = 0;
    for (s[0..n]) |c| {
        switch (c) {
            zero...nine => {
                d = d * 10 + @as(T, @intCast(c - zero));
            },
            else => {
                return error.InvalidString;
            },
        }
    }

    return d;
}

/// Assert unless `s` has at least `n` length.
fn mustHave(s: []const u8, n: usize) !void {
    if (s.len < n) {
        return error.InvalidString;
    }
}

/// Assert unless `s` begin with character `c`.
fn mustBeginWith(s: []const u8, c: u8) !void {
    if (s[0] != c) {
        return error.InvalidString;
    }
}

/// Count divisible numbers with `denom` between `from` and `to`.
/// The range is half open, `from` is included and `to` is excluded.
/// This assume `from < to`.
/// When `denom` is `0`, returns `errors.ZeroDivision`;
fn countDivisible(from: u16, to: u16, denom: u16) !u16 {
    return (try std.math.divCeil(u16, to, denom)) - (try std.math.divCeil(u16, from, denom));
}

/// Count Leap Year between years.
/// The range is half open, `from` is included and `to` is excluded.
/// Unless `from < to`, returns `error.InvalidRange`.
pub fn countLeapYear(from: u16, to: u16) !u16 {
    if (from >= to) {
        return error.InvalidRange;
    }

    // std.math.divCeil can raise ZeroDividion or Overflow,
    // neither of them never happen as long as denominator is positive integer.
    // Since from < to is guaranteed, subtraction cannot wrap.
    const n4 = countDivisible(from, to, 4) catch unreachable;
    const n100 = countDivisible(from, to, 100) catch unreachable;
    const n400 = countDivisible(from, to, 400) catch unreachable;

    return n4 - n100 + n400;
}

/// Get days in a month.
/// Aside from `std.time.getDaysInMonth()`,
/// this function takes `month` as `u4`
/// If `month` is outside, returns `error.InvalidMonth`.
pub fn getDaysInMonth(is_leap: bool, month: u4) !u5 {
    return switch (month) {
        4, 6, 9, 11 => 30,
        1, 3, 5, 7, 8, 10, 12 => 31,
        2 => if (is_leap) 29 else 28,
        else => error.InvalidMonth,
    };
}

/// Timestamp union tags based on the resolution of Timestamp.
const TimestampTag = enum { s, ms, us, ns };

/// Timestamp union
/// This union is used at `DateTime.fromTimestamp()`.
pub const Timestamp = union(TimestampTag) {
    s: i64,
    ms: i64,
    us: i64,
    ns: i128,

    const Self = @This();

    /// In order to create Time Zone awared Date Time,
    /// shift Timestamp.
    /// The shifted Timestampe is not true Timestamp,
    /// so that this method is private.
    fn addTimeZone(self: *Self, tz: TimeZone) !void {
        const sec = try tz.seconds();
        switch (self.*) {
            .s => |*s| {
                s.* += @as(i64, sec);
            },
            .ms => |*ms| {
                ms.* += @as(i64, sec) * std.time.ms_per_s;
            },
            .us => |*us| {
                us.* += @as(i64, sec) * std.time.us_per_s;
            },
            .ns => |*ns| {
                ns.* += @as(i128, sec) * std.time.ns_per_s;
            },
        }
    }

    /// Get nanoseconds representation
    pub fn nanoseconds(self: Self) i128 {
        return switch (self) {
            .s => |s| @as(i128, s) * std.time.ns_per_s,
            .ms => |ms| @as(i128, ms) * std.time.ns_per_ms,
            .us => |us| @as(i128, us) * std.time.ns_per_us,
            .ns => |ns| ns,
        };
    }

    /// Report whether self points same time to other timestamp.
    pub fn equal(self: Self, other: Self) bool {
        return self.nanoseconds() == other.nanoseconds();
    }
};

test "Timestamp" {
    var ts = Timestamp{ .s = 0 };

    try ts.addTimeZone(.{});
    try testing.expectEqualDeep(Timestamp{ .s = 0 }, ts);

    try ts.addTimeZone(.{ .hour = 9 });
    try testing.expectEqualDeep(Timestamp{ .s = 9 * 3600 }, ts);

    var tsn = Timestamp{ .ns = 0 };
    try tsn.addTimeZone(.{ .minute = 30 });
    try testing.expectEqualDeep(Timestamp{ .ns = 30 * 60 * 1_000_000_000 }, tsn);
}

/// `TimeZone` is used at `DateTime` field and `DateTime.fromTimestamp()`.
///
/// The signs of `hour` and `minute` fields must be same,
/// otherwise some `DateTime` methods will fail.
pub const TimeZone = struct {
    hour: i5 = 0,
    minute: i7 = 0,

    const Self = @This();

    /// Get seconds representation of Time Zone.
    pub fn seconds(self: Self) !i17 {
        try self.validate();

        const hour = @as(i17, self.hour) * std.time.s_per_hour;
        const minute = @as(i17, self.minute) * std.time.s_per_min;
        return hour + minute;
    }

    /// Assert when `TimeZone` is invalid.
    /// `hour` and `minute` must have same sign.
    pub fn validate(self: Self) !void {
        if ((self.hour == 0) or (self.minute == 0)) {
            return;
        }

        if ((self.hour > 0) != (self.minute > 0)) {
            return error.InvalidTimeZone;
        }
    }
};

const DurationTag = enum { days, hours, minutes, seconds, ms, us, ns };

/// `Duration` holds time interval
///
/// This is passed to `DateTime.addDuration()`.
///
/// `Duration` uses only apparent and fixed time interval,
/// so that the maximum unit is `days`.
pub const Duration = union(DurationTag) {
    days: i32,
    hours: i64,
    minutes: i64,
    seconds: i64,
    ms: i64,
    us: i64,
    ns: i128,

    const Self = @This();

    /// Get duration in nanoseconds
    pub fn nanoseconds(self: Self) i128 {
        return switch (self) {
            .days => |v| @as(i128, v) * std.time.ns_per_day,
            .hours => |v| @as(i128, v) * std.time.ns_per_hour,
            .minutes => |v| @as(i128, v) * std.time.ns_per_min,
            .seconds => |v| @as(i128, v) * std.time.ns_per_s,
            .ms => |v| @as(i128, v) * std.time.ns_per_ms,
            .us => |v| @as(i128, v) * std.time.ns_per_us,
            .ns => |v| v,
        };
    }
};

/// Sort Order
pub const SortOrder = enum(u2) { asc, desc };

/// `FormatSpec` specifies ISO8601 format mode.
pub const FormatSpec = enum {
    /// Basic format like `YYYYmmddTHHMMSS`
    basic,

    /// Extend format like `YYYY-mm-ddTHH:MM:SS`
    extended,
};

/// Format Resolution
pub const FormatResolution = enum {
    /// `YYYY-mm-ddTHH:MM`
    min,

    /// `YYYY-mm-ddTHH:MM:SS`
    s,

    /// `YYYY-mm-ddTHH:MM:SS.sss`
    ms,

    /// `YYYY-mm-ddTHH:MM:SS.ssssss`
    us,

    /// `YYYY-mm-ddTHH:MM:SS.sssssssss`
    ns,
};

/// Format Options
pub const FormatOptions = struct {
    /// ISO8061 basic or extended
    format: FormatSpec = .basic,

    /// Format resolution
    resolution: FormatResolution = .s,

    /// Whether `TimeZone` is included or not.
    tz: bool = true,
};

const DateTimeField = enum { year, month, date, hour, minute, second, ms, us, ns, tz_hour, tz_minute };

/// `DateTimeResolution` represents resolution of nice round timestamp
///
/// This is used at `DateTime.ceil()` and `DateTime.floor()`.
/// These functions round up or down the timestamp with this resolution.
///
/// `.ns` is noop and usually not useful.
pub const DateTimeResolution = enum {
    /// `??01-01-01T00:00:00.000000000+??:??`
    century,

    /// `????-01-01T00:00:00.000000000+??:??`
    year,

    /// `????-??-01T00:00:00.000000000+??:??`
    month,

    /// `????-??-??T00:00:00.000000000+??:??`
    date,

    /// `????-??-??T??:00:00.000000000+??:??`
    hour,

    /// `????-??-??T??:??:00.000000000+??:??`
    minute,

    /// `????-??-??T??:??:??.000000000+??:??`
    second,

    /// `????-??-??T??:??:??.???000000+??:??`
    ms,

    /// `????-??-??T??:??:??.??????000+??:??`
    us,

    /// `????-??-??T??:??:??.?????????+??:??`
    ///
    /// Usually, this resolution is not useful.
    ns,
};

/// `DateTime` holds Gregorian calendar timestamp with `TimeZone`.
///
/// Default values of fields are 1970-01-01T00:00:00Z.
/// You can set only necessary fields.
///
/// Leap second (aka. `second = 60`) is accepted and can be compared, however,
/// it is ignored when exporting to timestamp.
///
/// Since fields can be modified from outside,
/// methods validate its fields and return errors when it is invalid.
pub const DateTime = struct {
    /// `1 <= year`
    year: u16 = 1970,

    /// `1 <= month <= 12`
    month: u4 = 1,

    /// * `1 <= date <= 28` for `month == 2` and not leap year
    /// * `1 <= date <= 29` for `month == 2` and leap year
    /// * `1 <= date <= 30` for `month == 4, 6, 9, 11`
    /// * `1 <= date <= 31` for `month == 1, 3, 5, 7, 8, 10, 12`
    date: u5 = 1,

    /// `0 <= hour <= 23`
    hour: u5 = 0,

    /// `0 <= minute <= 59`
    minute: u6 = 0,

    /// `0 <= second <= 60`
    second: u6 = 0,

    /// `0 <= ms <= 999`
    ms: u10 = 0,

    /// `0 <= us <= 999`
    us: u10 = 0,

    /// `0 <= ns <= 999`
    ns: u10 = 0,

    /// Time Zone
    tz: TimeZone = .{},

    const Self = @This();

    /// Assert when `DateTime` is invalid.
    ///
    /// Following conditions are required.
    ///
    /// * `1 <= year`
    /// * `1 <= month <= 12`
    /// * `1 <= date <= getDaysInMonth(is_leap, month)`
    /// * `0 <= hour <= 23`
    /// * `0 <= minute <= 59`
    /// * `0 <= second <= 60`
    /// * `0 <= ms <= 999`
    /// * `0 <= us <= 999`
    /// * `0 <= ns <= 999`
    /// * `tz` is valid
    ///
    /// ## error
    /// Check from larger part (aka.  from `year`) to smaller (aka. `ns`), then `tz`.
    /// When any violations are found, corresponding error is returned.
    ///
    /// - `error.InvalidYear`
    /// - `error.InvalidDate`
    /// - `error.InvalidHour`
    /// - `error.InvalidMinute`
    /// - `error.InvalidSecond`
    /// - `error.InvalidMilliSecond`
    /// - `error.InvalidMicroSecond`
    /// - `error.InvalidNanoSecond`
    pub fn validate(self: Self) !void {
        if (self.year == 0) {
            return error.InvalidYear;
        }

        const is_leap = std.time.epoch.isLeapYear(self.year);
        if ((self.date == 0) or (self.date > try getDaysInMonth(is_leap, self.month))) {
            return error.InvalidDate;
        }

        if (self.hour >= 24) {
            return error.InvalidHour;
        }

        if (self.minute >= 60) {
            return error.InvalidMinute;
        }

        if (self.second > 60) {
            // Allow leap second
            return error.InvalidSecond;
        }

        if (self.ms >= 1000) {
            return error.InvalidMilliSecond;
        }

        if (self.us >= 1000) {
            return error.InvalidMicroSecond;
        }

        if (self.ns >= 1000) {
            return error.InvalidNanoSecond;
        }

        try self.tz.validate();
    }

    /// Report whether self points leap second.
    fn isLeapSecond(self: Self) bool {
        return self.second == 60;
    }

    /// Adjust time with second resolution
    fn adjustSecond(self: *Self, second: i64) void {
        self.second = @intCast(@mod(second, std.time.s_per_min));

        const minute = @divFloor(second, std.time.s_per_min);
        self.minute = @intCast(@mod(minute, 60));

        const hour = @divFloor(minute, 60);
        self.hour = @intCast(@mod(hour, 24));
    }

    /// Adjust time with ms resolution
    fn adjustMilli(self: *Self, ms: i64) void {
        self.ms = @intCast(@mod(ms, std.time.ms_per_s));

        const second = @divFloor(ms, std.time.ms_per_s);
        self.adjustSecond(second);
    }

    /// Adjust time with us resolution
    fn adjustMicro(self: *Self, us: i64) void {
        self.us = @intCast(@mod(us, std.time.us_per_ms));

        const ms = @divFloor(us, std.time.us_per_ms);
        self.adjustMilli(ms);
    }

    /// Adjust time with ns resolution
    fn adjustNano(self: *Self, ns: i128) void {
        self.ns = @intCast(@mod(ns, std.time.ns_per_us));

        const us: i64 = @intCast(@divFloor(ns, std.time.ns_per_us));
        self.adjustMicro(us);
    }

    /// Create new `DateTime` from `Timestamp` and `TimeZone`.
    ///
    /// ## Error
    /// - `error.InvalidTimeZone` unless `tz` is valid
    /// - `error.TooOld` if `timestamp` points older than `1970-01-01T00:00:00Z`
    pub fn fromTimestamp(timestamp: Timestamp, tz: TimeZone) !Self {
        var dt: DateTime = .{ .tz = tz };

        var ts = timestamp;
        try ts.addTimeZone(tz);

        switch (ts) {
            .ns => |ns| {
                dt.adjustNano(@mod(ns, std.time.ns_per_day));
            },
            .us => |us| {
                dt.adjustMicro(@mod(us, std.time.us_per_day));
            },
            .ms => |ms| {
                dt.adjustMilli(@mod(ms, std.time.ms_per_day));
            },
            .s => |s| {
                dt.adjustSecond(@mod(s, std.time.s_per_day));
            },
        }

        var days = switch (ts) {
            .ns => |ns| @as(i64, @intCast(@divFloor(ns, std.time.ns_per_day))),
            .us => |us| @as(i64, @divFloor(us, std.time.us_per_day)),
            .ms => |ms| @as(i64, @divFloor(ms, std.time.ms_per_day)),
            .s => |s| @as(i64, @divFloor(s, std.time.s_per_day)),
        };

        while (days < 0) {
            dt.year -= 1;
            if (dt.year == 0) {
                return error.TooOld;
            }

            const is_leap = std.time.epoch.isLeapYear(dt.year);
            days += if (is_leap) 366 else 365;
        }

        while (true) {
            const is_leap = std.time.epoch.isLeapYear(dt.year);
            const days_per_this_year: i64 = if (is_leap) 366 else 365;

            if (days < days_per_this_year) {
                break;
            }

            days -= days_per_this_year;
            dt.year += 1;
        }

        const is_leap = std.time.epoch.isLeapYear(dt.year);
        while (dt.month <= 12) {
            const days_per_this_month: i64 =
                @intCast(getDaysInMonth(is_leap, dt.month) catch unreachable);

            if (days < days_per_this_month) {
                break;
            }

            days -= days_per_this_month;
            dt.month += 1;
        } else unreachable;

        std.debug.assert(days <= 31);
        dt.date = @intCast(days + 1);
        return dt;
    }

    /// Set `Timestamp` and `TimeZone`
    /// When some error happens, the current `DateTime` is unchanged and still valid.
    pub fn setTimestamp(self: *Self, timestamp: Timestamp, tz: TimeZone) !void {
        self.* = try DateTime.fromTimestamp(timestamp, tz);
    }

    /// Get timestamp in seconds.
    pub fn getTimestamp(self: Self) !i64 {
        try self.validate();

        var timestamp: i64 = 0;
        if (self.year < 1970) {
            timestamp -=
                @as(i64, 1970 - self.year) * s_per_year +
                @as(i64, try countLeapYear(self.year, 1970)) * std.time.s_per_day;
        } else if (self.year > 1970) {
            timestamp +=
                @as(i64, self.year - 1970) * s_per_year +
                @as(i64, try countLeapYear(1970, self.year)) * std.time.s_per_day;
        }

        const is_leap = std.time.epoch.isLeapYear(self.year);
        var month: u4 = 1;
        while (month < self.month) : (month += 1) {
            timestamp +=
                @as(i64, try getDaysInMonth(is_leap, month)) *
                std.time.s_per_day;
        }

        timestamp +=
            @as(i64, self.date - 1) * std.time.s_per_day +
            @as(i64, self.hour) * std.time.s_per_hour +
            @as(i64, self.minute) * std.time.s_per_min +
            @as(i64, @min(self.second, 59)) - // Leap Second is ignored
            @as(i64, try self.tz.seconds());

        return timestamp;
    }

    /// Get timestamp in milli seconds.
    pub fn getMilliTimestamp(self: Self) !i64 {
        return try self.getTimestamp() * std.time.ms_per_s + self.ms;
    }

    /// Get timestamp in micro seconds.
    pub fn getMicroTimestamp(self: Self) !i64 {
        return try self.getMilliTimestamp() * std.time.us_per_ms + self.us;
    }

    /// Get timestamp in nano seconds.
    pub fn getNanoTimestamp(self: Self) !i128 {
        return @as(i128, try self.getMicroTimestamp()) * std.time.ns_per_us + self.ns;
    }

    /// Parse Time
    fn parseTime(self: *Self, date_string: []const u8, is_ext: bool) !([]const u8) {
        // HH
        self.hour = try parseInt(u5, date_string, 2);
        var s = date_string[2..];

        if (s.len == 0) {
            return s;
        }

        if (is_ext) {
            switch (s[0]) {
                // HH (allowed only when extended)
                '+', '-', 'Z' => {
                    return s;
                },
                ':' => {
                    s = s[1..];
                },
                else => {
                    return error.InvalidString;
                },
            }
        }

        // MM
        self.minute = try parseInt(u6, s, 2);
        s = s[2..];

        if (s.len == 0) {
            return s;
        }
        switch (s[0]) {
            '+', '-', 'Z' => {
                return s;
            },
            else => {},
        }

        if (is_ext) {
            try mustBeginWith(s, ':');
            s = s[1..];
        }

        // SS
        self.second = try parseInt(u6, s, 2);
        s = s[2..];

        if (s.len == 0) {
            return s;
        }
        switch (s[0]) {
            '+', '-', 'Z' => {
                return s;
            },
            '.' => {
                s = s[1..];
            },
            else => {
                return error.InvalidString;
            },
        }

        // ms
        self.ms = try parseInt(u10, s, 3);
        s = s[3..];

        if (s.len == 0) {
            return s;
        }
        switch (s[0]) {
            '+', '-', 'Z' => {
                return s;
            },
            else => {},
        }

        // us
        self.us = try parseInt(u10, s, 3);
        s = s[3..];

        if (s.len == 0) {
            return s;
        }
        switch (s[0]) {
            '+', '-', 'Z' => {
                return s;
            },
            else => {},
        }

        // ns
        self.ns = try parseInt(u10, s, 3);
        s = s[3..];

        return s;
    }

    /// Parse ISO8601 datetime string
    ///
    /// Both basic and extended ISO8601 datetime formats are accepted.
    ///
    /// ## Example
    /// ```zig
    /// // Extended format
    /// _ = try DateTime.parse("2024-04-01T00:15:00.234");
    /// // DateTime{ .year = 2024, .month = 4, .hour = 15, .ms = 234 }
    ///
    /// // Basic format with TimeZone
    /// _ = try DateTime.parse("19990705T150010-0723");
    /// ```
    pub fn parse(date_string: []const u8) !Self {
        var dt: DateTime = .{};

        // YYYY
        dt.year = try parseInt(u16, date_string, 4);
        var s = date_string[4..];

        if (s.len == 0) {
            try dt.validate();
            return dt;
        }

        const is_ext = (s[0] == '-');
        if (is_ext) {
            s = s[1..];
        }

        // mm
        dt.month = try parseInt(u4, s, 2);
        s = s[2..];

        if (is_ext) {
            if (s.len == 0) {
                // YYYY-mm (YYYYmm is not allowed)
                try dt.validate();
                return dt;
            }
            try mustBeginWith(s, '-');
            s = s[1..];
        }

        // dd
        dt.date = try parseInt(u5, s, 2);
        s = s[2..];

        if (s.len == 0) {
            try dt.validate();
            return dt;
        }

        // T
        try mustBeginWith(s, 'T');
        s = s[1..];

        // Time
        s = try dt.parseTime(s, is_ext);

        if (s.len == 0) {
            try dt.validate();
            return dt;
        }

        if (s[0] == 'Z') {
            try dt.validate();
            return dt;
        }

        switch (s[0]) {
            '+' => {
                s = s[1..];
                dt.tz.hour = try parseInt(i5, s, 2);
                s = s[2..];

                if (s.len == 0) {
                    try dt.validate();
                    return dt;
                }

                if (is_ext) {
                    try mustBeginWith(s, ':');
                    s = s[1..];
                }

                dt.tz.minute = try parseInt(i7, s, 2);
                s = s[2..];
            },
            '-' => {
                s = s[1..];
                dt.tz.hour = -try parseInt(i5, s, 2);
                s = s[2..];

                if (s.len == 0) {
                    try dt.validate();
                    return dt;
                }

                if (is_ext) {
                    try mustBeginWith(s, ':');
                    s = s[1..];
                }

                dt.tz.minute = -try parseInt(i7, s, 2);
                s = s[2..];
            },
            else => {
                return error.InvalidString;
            },
        }

        if (s.len != 0) {
            return error.InvalidString;
        }

        try dt.validate();
        return dt;
    }

    /// Parse and set ISO8061 string
    /// When some error happens, the current `DateTime` is unchanged and still valid.
    pub fn parseInto(self: *Self, date_string: []const u8) !void {
        self.* = try DateTime.parse(date_string);
    }

    /// Format field
    fn formatField(self: Self, writer: anytype, field: DateTimeField) !void {
        switch (field) {
            .year => {
                try writer.print("{d:0>4}", .{self.year});
            },
            .month => {
                try writer.print("{d:0>2}", .{self.month});
            },
            .date => {
                try writer.print("{d:0>2}", .{self.date});
            },
            .hour => {
                try writer.print("{d:0>2}", .{self.hour});
            },
            .minute => {
                try writer.print("{d:0>2}", .{self.minute});
            },
            .second => {
                try writer.print("{d:0>2}", .{self.second});
            },
            .ms => {
                try writer.print("{d:0>3}", .{self.ms});
            },
            .us => {
                try writer.print("{d:0>3}", .{self.us});
            },
            .ns => {
                try writer.print("{d:0>3}", .{self.ns});
            },
            .tz_hour => {
                try writer.print("{d:0>2}", .{@abs(self.tz.hour)});
            },
            .tz_minute => {
                try writer.print("{d:0>2}", .{@abs(self.tz.minute)});
            },
        }
    }

    /// Format up to second
    fn formatSecond(self: Self, writer: anytype, options: FormatOptions) !void {
        if (options.format == .extended) {
            _ = try writer.write(":");
        }
        try self.formatField(writer, .second);
    }

    /// Format up to ms
    fn formatSecToMilli(self: Self, writer: anytype, options: FormatOptions) !void {
        try self.formatSecond(writer, options);
        _ = try writer.write(".");
        try self.formatField(writer, .ms);
    }

    /// Format up to us
    fn formatSecToMicro(self: Self, writer: anytype, options: FormatOptions) !void {
        try self.formatSecToMilli(writer, options);
        try self.formatField(writer, .us);
    }

    /// Format up to ns
    fn formatSecToNano(self: Self, writer: anytype, options: FormatOptions) !void {
        try self.formatSecToMicro(writer, options);
        try self.formatField(writer, .ns);
    }

    /// Format to ISO8601 datetime string
    ///
    /// `writer` parameter is `std.io.Writer` interface or
    /// class with `write(self: Self, bytes []const u8) !void` and
    /// `print(self: Self, comptime format: []const u8, args: anytype) !void` methods.
    pub fn formatISO8601(self: Self, writer: anytype, options: FormatOptions) !void {
        try self.validate();

        // Year
        try self.formatField(writer, .year);

        if (options.format == .extended) {
            _ = try writer.write("-");
        }

        // Month
        try self.formatField(writer, .month);

        if (options.format == .extended) {
            _ = try writer.write("-");
        }

        // Date
        try self.formatField(writer, .date);

        _ = try writer.write("T");

        // Hour
        try self.formatField(writer, .hour);

        if (options.format == .extended) {
            _ = try writer.write(":");
        }

        // Minute
        try self.formatField(writer, .minute);

        switch (options.resolution) {
            .min => {},
            .s => {
                try self.formatSecond(writer, options);
            },
            .ms => {
                try self.formatSecToMilli(writer, options);
            },
            .us => {
                try self.formatSecToMicro(writer, options);
            },
            .ns => {
                try self.formatSecToNano(writer, options);
            },
        }

        if (options.tz) {
            const tz_sec = try self.tz.seconds();

            if (tz_sec == 0) {
                _ = try writer.write("Z");
                return;
            }

            if (tz_sec > 0) {
                _ = try writer.write("+");
            } else {
                _ = try writer.write("-");
            }

            try self.formatField(writer, .tz_hour);

            if (options.format == .extended) {
                _ = try writer.write(":");
            }

            try self.formatField(writer, .tz_minute);
        }
    }

    /// Format with custom format
    /// * `"%Y"` -> 4 digit year
    /// * `"%m"` -> 2 digit month
    /// * `"%d"` -> 2 digit date
    /// * `"%H"` -> 2 digit hour
    /// * `"%M"` -> 2 digit minute
    /// * `"%S"` -> 2 digit second
    /// * `"%f"` -> 6 digit fraction in us [0 ... 999999]
    /// * `"%N"` -> 9 digit fraction in ns [0 ... 999999999]
    /// * `"%F"` -> `"%Y-%m-%d"`
    /// * `"%R"` -> `"%H:%M"`
    /// * `"%T"` -> `"%H:%M:%S"`
    /// * `"%%"` -> Literal `'%'`
    ///
    /// Different from standard library, format (`fmt`) doesn't require `comptime`.
    pub fn formatCustom(self: Self, writer: anytype, fmt: []const u8) !void {
        try self.validate();

        var remained_fmt = fmt;
        while (remained_fmt.len > 0) {
            for (remained_fmt, 0..) |c, i| {
                switch (c) {
                    '%' => {
                        if (remained_fmt.len < i + 2) {
                            // Must not end with '%'
                            return error.InvalidFormat;
                        }
                        if (i > 0) {
                            _ = try writer.write(remained_fmt[0..i]);
                        }
                        switch (remained_fmt[i + 1]) {
                            'Y' => {
                                try self.formatField(writer, .year);
                            },
                            'm' => {
                                try self.formatField(writer, .month);
                            },
                            'd' => {
                                try self.formatField(writer, .date);
                            },
                            'H' => {
                                try self.formatField(writer, .hour);
                            },
                            'M' => {
                                try self.formatField(writer, .minute);
                            },
                            'S' => {
                                try self.formatField(writer, .second);
                            },
                            'f' => {
                                // Python datetime format and C strftime
                                try self.formatField(writer, .ms);
                                try self.formatField(writer, .us);
                            },
                            'N' => {
                                // GNU date command extension
                                try self.formatField(writer, .ms);
                                try self.formatField(writer, .us);
                                try self.formatField(writer, .ns);
                            },
                            'F' => {
                                // "%Y-%m-%d"
                                try self.formatField(writer, .year);
                                _ = try writer.write("-");
                                try self.formatField(writer, .month);
                                _ = try writer.write("-");
                                try self.formatField(writer, .date);
                            },
                            'R' => {
                                // "%H:%M"
                                try self.formatField(writer, .hour);
                                _ = try writer.write(":");
                                try self.formatField(writer, .minute);
                            },
                            'T' => {
                                // "%H:%M:%S"
                                try self.formatField(writer, .hour);
                                _ = try writer.write(":");
                                try self.formatField(writer, .minute);
                                _ = try writer.write(":");
                                try self.formatField(writer, .second);
                            },
                            'z' => {
                                if ((try self.tz.seconds()) >= 0) {
                                    _ = try writer.write("+");
                                } else {
                                    _ = try writer.write("-");
                                }
                                try self.formatField(writer, .tz_hour);
                                try self.formatField(writer, .tz_minute);
                            },
                            ':' => {
                                // "%:z" GNU date command extention
                                if (remained_fmt.len < i + 3) {
                                    return error.InvalidFormat;
                                }
                                switch (remained_fmt[i + 2]) {
                                    'z' => {
                                        if ((try self.tz.seconds()) >= 0) {
                                            _ = try writer.write("+");
                                        } else {
                                            _ = try writer.write("-");
                                        }
                                        try self.formatField(writer, .tz_hour);
                                        _ = try writer.write(":");
                                        try self.formatField(writer, .tz_minute);
                                    },
                                    else => {
                                        return error.InvalidFormat;
                                    },
                                }
                                // This branch consumes 1 additional character
                                remained_fmt = remained_fmt[1..];
                            },
                            '%' => {
                                _ = try writer.write("%");
                            },
                            else => {
                                return error.InvalidFormat;
                            },
                        }
                        remained_fmt = remained_fmt[i + 2 ..];
                        break;
                    },
                    else => {},
                }
            } else {
                // No '%' are found.
                _ = try writer.write(remained_fmt);
                remained_fmt = remained_fmt[remained_fmt.len..];
            }
        }
    }

    /// Report whether self is earlier than other.
    /// This method assumes both DateTime have equal TimeZone.
    fn earlierThanFast(self: Self, other: Self) !bool {
        try self.validate();
        try other.validate();

        return ((self.year < other.year) or
            (self.month < other.month) or
            (self.date < other.date) or
            (self.hour < other.hour) or
            (self.minute < other.minute) or
            (self.second < other.second) or
            (self.ms < other.ms) or
            (self.us < other.us) or
            (self.ns < other.ns));
    }

    /// Report whether self is earlier than other
    fn earlierThanSlow(self: Self, other: Self) !bool {
        const self_s = try self.getTimestamp();
        const other_s = try other.getTimestamp();

        if (self_s != other_s) {
            return self_s < other_s;
        }

        const self_leap = self.isLeapSecond();
        const other_leap = other.isLeapSecond();

        if (self_leap != other_leap) {
            // Only one of them points leap second
            // If other points leap second, self < other.
            return other_leap;
        }

        if (self.ms != other.ms) {
            return self.ms < other.ms;
        }

        if (self.us != other.us) {
            return self.us < other.us;
        }

        return self.ns < other.ns;
    }

    /// Report whether self is earlier than other.
    /// This method fails when any of self and other are invalid.
    pub fn earlierThan(self: Self, other: Self) !bool {
        if (std.meta.eql(self.tz, other.tz)) {
            return try self.earlierThanFast(other);
        }
        return try self.earlierThanSlow(other);
    }

    /// Report whether self is later than other.
    /// This method fails when any of self and other are invalid.
    pub fn laterThan(self: Self, other: Self) !bool {
        return try other.earlierThan(self);
    }

    /// Report whether self is earlier than other.
    /// This method assumes both DateTime have equal TimeZone.
    fn equalFast(self: Self, other: Self) !bool {
        try self.validate();
        try other.validate();

        return ((self.year == other.year) and
            (self.month == other.month) and
            (self.date == other.date) and
            (self.hour == other.hour) and
            (self.minute == other.minute) and
            (self.second == other.second) and
            (self.ms == other.ms) and
            (self.us == other.us) and
            (self.ns == other.ns));
    }

    /// Report whether self is equal to other.
    fn equalSlow(self: Self, other: Self) !bool {
        const self_ns = try self.getNanoTimestamp();
        const other_ns = try other.getNanoTimestamp();

        return (self_ns == other_ns) and (self.isLeapSecond() == other.isLeapSecond());
    }

    /// Report whether self points equal timestamp with other.
    /// This method fails when any of self and other are invalid.
    pub fn equal(self: Self, other: Self) !bool {
        if (std.meta.eql(self.tz, other.tz)) {
            return try self.equalFast(other);
        }
        return try self.equalSlow(other);
    }

    /// Get day of the week
    pub fn dayOfWeek(self: Self) !DayOfWeek {
        try self.validate();

        // (Gregorianum) 0001-01-01 is Monday.
        var day: u16 = 1;

        if (self.year > 1) {
            // YYYY-01-01
            day = @mod(day + (self.year - 1) +
                (countLeapYear(1, self.year) catch unreachable), 7);
        }

        if (self.month > 1) {
            // YYYY-mm-01
            const is_leap = std.time.epoch.isLeapYear(self.year);
            for (1..self.month) |month| {
                const days_in_month = getDaysInMonth(is_leap, @intCast(month)) catch unreachable;
                day = @mod(day + @as(u16, days_in_month), 7);
            }
        }

        if (self.date > 1) {
            day = @mod(day + self.date - 1, 7);
        }

        return @enumFromInt(day);
    }

    /// Get day of the year. (1 for 1st January)
    pub fn dayOfYear(self: Self) !u16 {
        try self.validate();

        var days: u16 = @intCast(self.date);
        if (self.month > 1) {
            const is_leap = std.time.epoch.isLeapYear(self.year);
            for (1..self.month) |m| {
                days += getDaysInMonth(is_leap, @intCast(m)) catch unreachable;
            }
        }

        return days;
    }

    /// Sort asc function for `std.mem.sort()`
    /// Since it doesn't allow any errors,
    /// call `@panic` builtin when an error happens.
    fn sortAscFn(_: void, lhs: Self, rhs: Self) bool {
        return lhs.earlierThan(rhs) catch @panic("Invalid DateTime");
    }

    /// Sort desc function for `std.mem.sort()`
    /// Since it doesn't allow any errors,
    /// call `@panic` builtin when an error happens.
    fn sortDescFn(_: void, lhs: Self, rhs: Self) bool {
        return lhs.laterThan(rhs) catch @panic("Invalid DateTime");
    }

    /// Sort `DateTime` slice
    ///
    /// Sort order (`order`) must be `comptime`.
    ///
    /// This is the wrapper function of `std.mem.sort()` for `[]DateTime`.
    pub fn sort(date_array: []Self, comptime order: SortOrder) !void {
        for (date_array) |dt| {
            try dt.validate();
        }

        const f = switch (order) {
            .asc => Self.sortAscFn,
            .desc => Self.sortDescFn,
        };

        std.mem.sort(Self, date_array, {}, f);
    }

    /// Change `TimeZone`
    pub fn changeTimeZone(self: *Self, tz: TimeZone) !void {
        if (std.meta.eql(self.tz, tz)) {
            return;
        }
        self.* = try DateTime.fromTimestamp(.{ .ns = try self.getNanoTimestamp() }, tz);
    }

    /// Add `Duration`
    ///
    /// `TimeZone` doesn't change
    pub fn addDuration(self: *Self, duration: Duration) !void {
        const ns = duration.nanoseconds();
        if (ns == 0) {
            return;
        }

        self.* = try DateTime.fromTimestamp(
            .{ .ns = try self.getNanoTimestamp() + ns },
            self.tz,
        );
    }

    /// Round up (go to future) to nice round timestamp with `DateTimeResolution`
    pub fn ceil(self: *Self, resolution: DateTimeResolution) !void {
        try self.validate();

        switch (resolution) {
            .century => {
                const yy = @mod(self.year, 100);
                if ((yy == 1) and (self.month == 1) and (self.date == 1) and
                    (self.hour == 0) and (self.minute == 0) and (self.second == 0) and
                    (self.ms == 0) and (self.us == 0) and (self.ns == 0))
                {
                    return;
                }
                self.floor(.century) catch unreachable;
                self.year += 100;
            },
            .year => {
                if ((self.month == 1) and (self.date == 1) and
                    (self.hour == 0) and (self.minute == 0) and (self.second == 0) and
                    (self.ms == 0) and (self.us == 0) and (self.ns == 0))
                {
                    return;
                }
                self.floor(.year) catch unreachable;
                self.year += 1;
            },
            .month => {
                if ((self.date == 1) and (self.hour == 0) and
                    (self.minute == 0) and (self.second == 0) and
                    (self.ms == 0) and (self.us == 0) and (self.ns == 0))
                {
                    return;
                }
                self.floor(.month) catch unreachable;
                if (self.month < 12) {
                    self.month += 1;
                } else {
                    self.year += 1;
                    self.month = 1;
                }
            },
            .date => {
                if ((self.hour == 0) and (self.minute == 0) and (self.second == 0) and
                    (self.ms == 0) and (self.us == 0) and (self.ns == 0))
                {
                    return;
                }
                self.floor(.date) catch unreachable;

                const is_leap = std.time.epoch.isLeapYear(self.year);
                const days = getDaysInMonth(is_leap, self.month) catch unreachable;
                if (self.date < days) {
                    self.date += 1;
                } else {
                    try self.addDuration(.{ .days = 1 });
                }
            },
            .hour => {
                if ((self.minute == 0) and
                    (self.second == 0) and
                    (self.ms == 0) and
                    (self.us == 0) and
                    (self.ns == 0))
                {
                    return;
                }
                self.floor(.hour) catch unreachable;
                if (self.hour < 23) {
                    self.hour += 1;
                } else {
                    try self.addDuration(.{ .hours = 1 });
                }
            },
            .minute => {
                if ((self.second == 0) and
                    (self.ms == 0) and
                    (self.us == 0) and
                    (self.ns == 0))
                {
                    return;
                }
                self.floor(.minute) catch unreachable;
                if (self.minute < 59) {
                    self.minute += 1;
                } else {
                    try self.addDuration(.{ .minutes = 1 });
                }
            },
            .second => {
                if ((self.ms == 0) and (self.us == 0) and (self.ns == 0)) {
                    return;
                }
                if (self.second < 59) {
                    self.second += 1;
                    self.ms = 0;
                    self.us = 0;
                    self.ns = 0;
                } else {
                    const s = (self.getTimestamp() catch unreachable) + 1;
                    self.* = try DateTime.fromTimestamp(.{ .s = s }, self.tz);
                }
            },
            .ms => {
                if ((self.us == 0) and (self.ns == 0)) {
                    return;
                }
                if (self.ms < 999) {
                    self.ms += 1;
                    self.us = 0;
                    self.ns = 0;
                } else {
                    const ms = (self.getMilliTimestamp() catch unreachable) + 1;
                    self.* = try DateTime.fromTimestamp(.{ .ms = ms }, self.tz);
                }
            },
            .us => {
                if (self.ns == 0) {
                    return;
                }
                if (self.us < 999) {
                    self.us += 1;
                    self.ns = 0;
                } else {
                    const us = (self.getMicroTimestamp() catch unreachable) + 1;
                    self.* = try DateTime.fromTimestamp(.{ .us = us }, self.tz);
                }
            },
            .ns => {},
        }
    }

    /// Round down (go to past) to nice round timestamp with `DateTimeResolution`
    pub fn floor(self: *Self, resolution: DateTimeResolution) !void {
        try self.validate();

        switch (resolution) {
            .century => {
                self.year -= switch (@mod(self.year, 100)) {
                    0 => 99,
                    else => |yy| yy - 1,
                };
                self.month = 1;
                self.date = 1;
                self.hour = 0;
                self.minute = 0;
                self.second = 0;
                self.ms = 0;
                self.us = 0;
                self.ns = 0;
            },
            .year => {
                self.month = 1;
                self.date = 1;
                self.hour = 0;
                self.minute = 0;
                self.second = 0;
                self.ms = 0;
                self.us = 0;
                self.ns = 0;
            },
            .month => {
                self.date = 1;
                self.hour = 0;
                self.minute = 0;
                self.second = 0;
                self.ms = 0;
                self.us = 0;
                self.ns = 0;
            },
            .date => {
                self.hour = 0;
                self.minute = 0;
                self.second = 0;
                self.ms = 0;
                self.us = 0;
                self.ns = 0;
            },
            .hour => {
                self.minute = 0;
                self.second = 0;
                self.ms = 0;
                self.us = 0;
                self.ns = 0;
            },
            .minute => {
                self.second = 0;
                self.ms = 0;
                self.us = 0;
                self.ns = 0;
            },
            .second => {
                self.ms = 0;
                self.us = 0;
                self.ns = 0;
            },
            .ms => {
                self.us = 0;
                self.ns = 0;
            },
            .us => {
                self.ns = 0;
            },
            .ns => {},
        }
    }
};
