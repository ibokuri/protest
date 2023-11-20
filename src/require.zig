const std = @import("std");

const print = std.debug.print;
const test_ally = std.testing.allocator;

/// Reports a failure.
pub inline fn fail(fail_msg: []const u8) !void {
    return try failf(fail_msg, "", .{});
}

/// Reports a failure.
pub inline fn failf(fail_msg: []const u8, comptime msg: []const u8, args: anytype) !void {
    comptime checkArgs(args);

    var content = content: {
        const cap: usize = if (msg.len == 0) 2 else 3;
        break :content try std.ArrayList(LabelContent).initCapacity(test_ally, cap);
    };
    defer content.deinit();

    content.appendAssumeCapacity(.{
        .label = "Error",
        .content = fail_msg,
    });

    var formatted_msg = formatted_msg: {
        var formatted_msg = try std.ArrayList(u8).initCapacity(test_ally, msg.len);
        errdefer formatted_msg.deinit();

        if (msg.len > 0) {
            try std.fmt.format(formatted_msg.writer(), msg, args);

            content.appendAssumeCapacity(.{
                .label = "Message",
                .content = formatted_msg.items,
            });
        }
        break :formatted_msg formatted_msg;
    };
    defer formatted_msg.deinit();

    content.appendAssumeCapacity(.{
        .label = "Error Trace",
        .content = "",
    });

    const output = try labelOutput(content.items);
    defer test_ally.free(output);

    print("\r\n\n", .{});
    print("{s}\n", .{output});

    return error.AssertionError;
}

/// Asserts that the specified value is false.
///
/// ```
/// require.isFalse(true);
/// ```
pub inline fn isFalse(value: bool) !void {
    return try isFalsef(value, "", .{});
}

/// Asserts that the specified value is false.
///
/// ```
/// require.isFalsef(true, "helpful error {s}", .{"message"});
/// ```
pub inline fn isFalsef(value: bool, comptime msg: []const u8, args: anytype) !void {
    comptime checkArgs(args);

    if (value) {
        return try failf("Should be false", msg, args);
    }
}

/// Asserts that the first value is greater than the second.
///
/// ```
/// require.isGreater(1, 2);
/// ```
pub inline fn isGreater(v1: anytype, v2: @TypeOf(v1)) !void {
    return try isGreaterf(v1, v2, "", .{});
}

/// Asserts that the first value is greater than the second.
///
/// ```
/// require.isGreaterf(1, 2, "helpful error {s}", .{"message"});
/// ```
pub inline fn isGreaterf(v1: anytype, v2: @TypeOf(v1), comptime msg: []const u8, args: anytype) !void {
    comptime checkArgs(args);
    comptime checkComparable(@TypeOf(v1));

    if (v1 <= v2) {
        var fail_msg = std.ArrayList(u8).init(test_ally);
        defer fail_msg.deinit();
        try std.fmt.format(fail_msg.writer(), "'{}' is not greater than '{}'", .{ v1, v2 });

        return try failf(fail_msg.items, msg, args);
    }
}

/// Asserts that the first value is greater than or equal to the second.
///
/// ```
/// require.isGreaterOrEqual(1, 2);
/// ```
pub inline fn isGreaterOrEqual(v1: anytype, v2: @TypeOf(v1)) !void {
    return try isGreaterOrEqualf(v1, v2, "", .{});
}

/// Asserts that the first value is greater than or equal to the second.
///
/// ```
/// require.isGreaterOrEqualf(1, 2, "helpful error {s}", .{"message"});
/// ```
pub inline fn isGreaterOrEqualf(v1: anytype, v2: @TypeOf(v1), comptime msg: []const u8, args: anytype) !void {
    comptime checkArgs(args);
    comptime checkComparable(@TypeOf(v1));

    {
        const v1_info = @typeInfo(@TypeOf(v1));

        if (v1_info != .Int or v1_info != .Float) {
            const err = std.fmt.comptimePrint("expected integers or floats, found '{s}'", .{@typeName(v1_info)});
            @compileError(err);
        }
    }

    if (v1 < v2) {
        var fail_msg = std.ArrayList(u8).init(test_ally);
        defer fail_msg.deinit();
        try std.fmt.format(fail_msg.writer(), "'{}' is not greater than '{}'", .{ v1, v2 });

        return try failf(fail_msg.items, msg, args);
    }
}

/// Asserts that the first value is less than the second.
///
/// ```
/// require.isLess(1, 2);
/// ```
pub inline fn isLess(v1: anytype, v2: @TypeOf(v1)) !void {
    return try isLessf(v1, v2, "", .{});
}

/// Asserts that the first value is less than the second.
///
/// ```
/// require.isLessf(2, 1, "helpful error {s}", .{"message"});
/// ```
pub inline fn isLessf(v1: anytype, v2: @TypeOf(v1), comptime msg: []const u8, args: anytype) !void {
    comptime checkArgs(args);
    comptime checkComparable(@TypeOf(v1));

    if (v1 >= v2) {
        var fail_msg = std.ArrayList(u8).init(test_ally);
        defer fail_msg.deinit();
        try std.fmt.format(fail_msg.writer(), "'{}' is not less than '{}'", .{ v1, v2 });

        return try failf(fail_msg.items, msg, args);
    }
}

/// Asserts that the first value is less than or equal to the second.
///
/// ```
/// require.isLessOrEqual(2, 1);
/// ```
pub inline fn isLessOrEqual(v1: anytype, v2: @TypeOf(v1)) !void {
    return try isLessOrEqualf(v1, v2, "", .{});
}

/// Asserts that the first value is less than or equal to the second.
///
/// ```
/// require.isLessOrEqualf(2, 1, "helpful error {s}", .{"message"});
/// ```
pub inline fn isLessOrEqualf(v1: anytype, v2: @TypeOf(v1), comptime msg: []const u8, args: anytype) !void {
    comptime checkArgs(args);
    comptime checkComparable(@TypeOf(v1));

    if (v1 > v2) {
        var fail_msg = std.ArrayList(u8).init(test_ally);
        defer fail_msg.deinit();
        try std.fmt.format(fail_msg.writer(), "'{}' is not less than '{}'", .{ v1, v2 });

        return try failf(fail_msg.items, msg, args);
    }
}

/// Asserts that the specified value is null.
///
/// ```
/// require.isNull(123);
/// ```
pub inline fn isNull(value: anytype) !void {
    return try isNullf(value, "", .{});
}

/// Asserts that the specified value is null.
///
/// ```
/// require.isNullf(123, "helpful error {s}", .{"message"});
/// ```
pub inline fn isNullf(value: anytype, comptime msg: []const u8, args: anytype) !void {
    comptime checkArgs(args);

    const info = @typeInfo(@TypeOf(value));

    if (info == .Null or (info == .Optional and value == null)) {
        return;
    }

    var fail_msg = std.ArrayList(u8).init(test_ally);
    defer fail_msg.deinit();

    switch (info) {
        .Null => unreachable, // UNREACHABLE: null values always exit early.
        .Optional => try std.fmt.format(fail_msg.writer(), "expected null, found '{any}'", .{value.?}),
        else => try std.fmt.format(fail_msg.writer(), "expected null, found '{any}'", .{value}),
    }

    return try failf(fail_msg.items, msg, args);
}

/// Asserts that the specified value is true.
///
/// ```
/// require.isTrue(false);
/// ```
pub inline fn isTrue(value: bool) !void {
    return try isTrue(value, "", .{});
}

/// Asserts that the specified value is true.
///
/// ```
/// require.isTruef(false, "helpful error {s}", .{"message"});
/// ```
pub inline fn isTruef(value: bool, comptime msg: []const u8, args: anytype) !void {
    comptime checkArgs(args);

    if (!value) {
        return try failf("Should be true", msg, args);
    }
}

const LabelContent = struct {
    label: []const u8,
    content: []const u8,
};

fn labelOutput(contents: []const LabelContent) ![]const u8 {
    const longest_label_len: usize = longest_label_len: {
        var len: usize = 0;
        for (contents) |v| {
            if (v.label.len > len) {
                len = v.label.len;
            }
        }
        break :longest_label_len len;
    };

    var output = std.ArrayList(u8).init(test_ally);
    errdefer output.deinit();

    for (contents) |v| {
        // Label
        try output.append('\t');
        try output.appendSlice(v.label);
        try output.append(':');

        // Separator
        try output.appendNTimes(' ', longest_label_len - v.label.len);

        // Content
        try output.append('\t');
        const iml = try indentMessageLines(v.content, longest_label_len);
        defer test_ally.free(iml);
        try output.appendSlice(iml);

        // Newline
        try output.append('\n');
    }

    return output.toOwnedSlice();
}

fn indentMessageLines(msg: []const u8, longest_label_len: usize) ![]const u8 {
    var output = std.ArrayList(u8).init(test_ally);
    errdefer output.deinit();

    var fbs = std.io.fixedBufferStream(msg);
    const fbs_r = fbs.reader();
    var br = std.io.bufferedReader(fbs_r);
    const br_r = br.reader();

    {
        var i: usize = 0;

        while (try br_r.readUntilDelimiterOrEofAlloc(test_ally, '\n', 10_000)) |buf| : (i += 1) {
            defer test_ally.free(buf);

            if (i != 0) {
                try output.appendSlice(&.{ '\n', '\t' });
                try output.appendNTimes(' ', longest_label_len + 1);
                try output.append('\t');
            }

            try output.appendSlice(buf);
        }
    }

    return output.toOwnedSlice();
}

fn checkArgs(args: anytype) void {
    comptime {
        const T = @TypeOf(args);
        const info = @typeInfo(T);

        if (info != .Struct or !info.Struct.is_tuple) {
            @compileError(std.fmt.comptimePrint(
                "expected 'args' to be a tuple, found '{s}'",
                .{@typeName(T)},
            ));
        }
    }
}

fn checkComparable(comptime T: type) void {
    comptime {
        const info = @typeInfo(T);

        if (info != .Int or info != .Float) {
            const err = std.fmt.comptimePrint(
                "expected integers or floats, found '{s}'",
                .{@typeName(info)},
            );

            @compileError(err);
        }
    }
}
