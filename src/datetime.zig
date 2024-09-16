//! datetime.zig
//!
//! # DateTime
//! Time Zone awared Date Time struct
//!
//! # Timestamp
//!
//! # TimeZone

const std = @import("std");
const testing = std.testing;

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

test "countLeapYear" {
    try testing.expectEqual(1, countLeapYear(2000, 2001));
    try testing.expectEqual(0, countLeapYear(2001, 2002));
    try testing.expectEqual(2, countLeapYear(2000, 2005));
    try testing.expectEqual(0, countLeapYear(1900, 1901));
    try testing.expectError(error.InvalidRange, countLeapYear(1900, 1900));
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

/// Time Zone struct
/// This struct is used at `DateTime` field and `DateTime.fromTimestamp()`.
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
    fn validate(self: Self) !void {
        if ((self.hour == 0) or (self.minute == 0)) {
            return;
        }

        if ((self.hour > 0) != (self.minute > 0)) {
            return error.InvalidTimeZone;
        }
    }
};

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

/// Sort Order
pub const SortOrder = enum(u2) { asc, desc };

/// DateTime struct
pub const DateTime = struct {
    year: u16 = 1970,
    month: u4 = 1,
    date: u5 = 1,
    hour: u5 = 0,
    minute: u6 = 0,
    second: u6 = 0,
    ms: u10 = 0,
    us: u10 = 0,
    ns: u10 = 0,
    tz: TimeZone = .{},

    const Self = @This();

    /// Assert when `DateTime` is invalid.
    ///    1 <= year
    ///    1 <= month <= 12
    ///    1 <= date <= getDaysInMonth(is_leap, month)
    ///    0 <= hour <= 23
    ///    0 <= minute <= 59
    ///    0 <= second <= 59
    ///    0 <= ms <= 999
    ///    0 <= us <= 999
    ///    0 <= ns <= 999
    ///    tz is valid
    fn validate(self: Self) !void {
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

        if (self.second >= 60) {
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

            if (days <= days_per_this_month) {
                break;
            }

            days -= days_per_this_month;
            dt.month += 1;
        } else unreachable;

        dt.date = @intCast(days + 1);
        return dt;
    }

    /// Set Timestamp
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
            @as(i64, self.second) -
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

    /// Parse ISO8601 string
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

    /// Report whether self is earlier than other.
    /// This method fails when any of self and other are invalid.
    pub fn earlierThan(self: Self, other: Self) !bool {
        if (std.meta.eql(self.tz, other.tz)) {
            return try self.earlierThanFast(other);
        }
        return (try self.getNanoTimestamp()) < (try other.getNanoTimestamp());
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

    /// Report whether self points equal timestamp with other.
    /// This method fails when any of self and other are invalid.
    pub fn equal(self: Self, other: Self) !bool {
        if (std.meta.eql(self.tz, other.tz)) {
            return try self.equalFast(other);
        }
        return (try self.getNanoTimestamp()) == (try other.getNanoTimestamp());
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

    /// Sort DateTime slice
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

    /// Change TimeZone
    pub fn changeTimeZone(self: *Self, tz: TimeZone) !void {
        if(std.meta.eql(self.tz, tz)){
            return;
        }
        self.* = try DateTime.fromTimestamp(.{ .ns = try self.getNanoTimestamp() }, tz);
    }
};

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
    try testing.expectError(error.InvalidSecond, (DateTime{ .second = 60 }).validate());
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
