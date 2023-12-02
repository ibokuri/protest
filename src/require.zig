const std = @import("std");

const print = std.debug.print;
const test_ally = std.testing.allocator;

/// Asserts that the specified string or list (array, slice, tuple) contains
/// the specified substring or element.
///
/// ```
/// try require.contains("Hello World", "World");
/// try require.contains("Hello World", 'W');
/// try require.contains([_]bool{ true, false }, true);
/// ```
pub inline fn contains(haystack: anytype, needle: anytype) !void {
    try containsf(haystack, needle, "", .{});
}

/// Asserts that the specified string, list(array, slice...) or map
/// contains the specified substring or element.
///
/// ```
/// try require.containsf("Hello World", "World", "helpful error {s}", .{"message"});
/// try require.containsf("Hello World", 'W', "helpful error {s}", .{"message"});
/// try require.containsf([_]bool{ true, false }, true, "helpful error {s}", .{"message"});
/// ```
pub inline fn containsf(
    haystack: anytype,
    needle: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    const Haystack = @TypeOf(haystack);
    const Needle = @TypeOf(needle);

    if (!containsElement(haystack, needle)) {
        const fmt = comptime fmt: {
            const haystack_is_str = isString(Haystack);
            const needle_is_str = isString(Needle);

            if (haystack_is_str and needle_is_str) break :fmt 
            \\"{s}" does not contain "{s}"
            ;

            if (!haystack_is_str and !needle_is_str) break :fmt 
            \\{any} does not contain {any}
            ;

            if (haystack_is_str) break :fmt 
            \\"{s}" does not contain "{u}"
            ;

            if (needle_is_str) break :fmt 
            \\{any} does not contain "{s}"
            ;
        };
        const fail_msg = try failMsg(fmt, .{ haystack, needle });
        defer test_ally.free(fail_msg);

        try failf(fail_msg, msg, args);
    }
}

/// Asserts that two values are equal.
///
/// ```
/// try require.equal(123, 123);
/// ```
pub inline fn equal(expected: anytype, value: anytype) !void {
    try equalf(expected, value, "", .{});
}

/// Asserts that two values are equal.
///
/// ```
/// try require.equalf(123, 123, "helpful error {s}", .{"message"});
/// ```
pub inline fn equalf(
    expected: anytype,
    value: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    const Expected = @TypeOf(expected);
    const Value = @TypeOf(value);

    if (!deepEqual(expected, value)) {
        const fmt = comptime fmt: {
            const expected_str = isString(Expected);
            const value_str = isString(Value);

            if (expected_str and value_str) {
                break :fmt 
                \\Not equal:
                \\expected: "{s}"
                \\actual:   "{s}"
                ;
            }

            if (!expected_str and !value_str) {
                break :fmt 
                \\Not equal:
                \\expected: {any}
                \\actual:   {any}
                ;
            }

            if (expected_str) {
                break :fmt 
                \\Not equal:
                \\expected: "{s}"
                \\actual:   {any}
                ;
            }

            if (value_str) {
                break :fmt 
                \\Not equal:
                \\expected: {any}
                \\actual:   "{s}"
                ;
            }
        };
        const fail_msg = try failMsg(fmt, .{ expected, value });
        defer test_ally.free(fail_msg);

        try failf(fail_msg, msg, args);
    }
}

/// Asserts that the provided value is an error and that it is equal to the
/// provided error.
///
/// ```
/// try require.equalError(error.Foo, error.Foo);
/// ```
pub inline fn equalError(
    expected: anyerror,
    value: anyerror,
) !void {
    try equalErrorf(expected, value, "", .{});
}

/// Asserts that the provided value is an error and that it is equal to the
/// provided error.
///
/// ```
/// try require.equalErrorf(error.Foo, error.Foo, "helpful error {s}", .{"message"});
/// ```
pub inline fn equalErrorf(
    expected: anyerror,
    value: anyerror,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);

    const info = @typeInfo(@TypeOf(value));

    if (info != .ErrorSet) {
        const fail_msg = try failMsg("Expected error, found '{}'", .{value});
        defer test_ally.free(fail_msg);

        try failf(fail_msg, msg, args);
    }

    if (value != expected) {
        const fail_msg = try failMsg(
            \\Error not equal:
            \\expected: {}
            \\value:   {}
        , .{ expected, value });
        defer test_ally.free(fail_msg);
        try failf(fail_msg, msg, args);
    }
}

/// Asserts that the specified value is of the specified type.
///
/// ```
/// try require.equalType(bool, true);
/// ```
pub inline fn equalType(
    comptime Expected: type,
    value: anytype,
) !void {
    try equalTypef(Expected, value, "", .{});
}

/// Asserts that the specified value is of the specified type.
///
/// ```
/// try require.equalTypef(bool, true, "helpful error {s}", .{"message"});
/// ```
pub inline fn equalTypef(
    comptime Expected: type,
    value: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);

    const Value = @TypeOf(value);

    if (Expected != Value) {
        const fail_msg = try failMsg(
            "Expected type '{s}', found '{s}'",
            .{ @typeName(Expected), @typeName(Value) },
        );
        defer test_ally.free(fail_msg);

        try failf(fail_msg, msg, args);
    }
}

/// Reports a failure.
pub inline fn fail(fail_msg: []const u8) !void {
    try failf(fail_msg, "", .{});
}

/// Reports a failure.
pub inline fn failf(
    fail_msg: []const u8,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);

    var content = content: {
        const cap: usize = if (msg.len == 0) 2 else 3;
        break :content try std.ArrayList(LabelContent).initCapacity(
            test_ally,
            cap,
        );
    };
    defer content.deinit();

    content.appendAssumeCapacity(.{
        .label = "Error",
        .content = fail_msg,
    });

    var formatted_msg = formatted_msg: {
        var formatted_msg = try std.ArrayList(u8).initCapacity(
            test_ally,
            msg.len,
        );
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

/// Asserts that a value is an error.
///
/// ```
/// try require.isError(error.Foobar);
/// ```
pub inline fn isError(value: anytype) !void {
    try isErrorf(value, "", .{});
}

/// Asserts that a value is an error.
///
/// ```
/// try require.isErrorf(error.Foobar, "helpful error {s}", .{"message"});
/// ```
pub inline fn isErrorf(
    value: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);

    if (@typeInfo(@TypeOf(value)) != .ErrorSet) {
        const fail_msg = try failMsg("Expected error, found '{any}'", .{value});
        defer test_ally.free(fail_msg);

        try failf(fail_msg, msg, args);
    }
}

/// Asserts that the specified value is false.
///
/// ```
/// try require.isFalse(false);
/// ```
pub inline fn isFalse(value: bool) !void {
    try isFalsef(value, "", .{});
}

/// Asserts that the specified value is false.
///
/// ```
/// try require.isFalsef(false, "helpful error {s}", .{"message"});
/// ```
pub inline fn isFalsef(
    value: bool,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);

    if (value) {
        try failf("Should be false", msg, args);
    }
}

/// Asserts that the first value is greater than the second.
///
/// ```
/// try require.isGreater(2, 1);
/// try require.isGreater(2.0, 1.0);
/// ```
pub inline fn isGreater(v1: anytype, v2: @TypeOf(v1)) !void {
    try isGreaterf(v1, v2, "", .{});
}

/// Asserts that the first value is greater than the second.
///
/// ```
/// try require.isGreaterf(2, 1, "helpful error {s}", .{"message"});
/// try require.isGreaterf(2.0, 1.0, "helpful error {s}", .{"message"});
/// ```
pub inline fn isGreaterf(
    v1: anytype,
    v2: @TypeOf(v1),
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);
    comptime checkComparable(@TypeOf(v1));

    if (v1 <= v2) {
        const fail_msg = try failMsg(
            "'{}' is not greater than '{}'",
            .{ v1, v2 },
        );
        defer test_ally.free(fail_msg);

        try failf(fail_msg, msg, args);
    }
}

/// Asserts that the first value is greater than or equal to the second.
///
/// ```
/// try require.isGreaterOrEqual(1, 1);
/// try require.isGreaterOrEqual(1.0, 1.0);
/// ```
pub inline fn isGreaterOrEqual(v1: anytype, v2: @TypeOf(v1)) !void {
    try isGreaterOrEqualf(v1, v2, "", .{});
}

/// Asserts that the first value is greater than or equal to the second.
///
/// ```
/// try require.isGreaterOrEqualf(1, 1, "helpful error {s}", .{"message"});
/// try require.isGreaterOrEqualf(1.0, 1.0, "helpful error {s}", .{"message"});
/// ```
pub inline fn isGreaterOrEqualf(
    v1: anytype,
    v2: @TypeOf(v1),
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);
    comptime checkComparable(@TypeOf(v1));

    if (v1 < v2) {
        const fail_msg = try failMsg(
            "'{}' is not greater than or equal to '{}'",
            .{ v1, v2 },
        );
        defer test_ally.free(fail_msg);

        try failf(fail_msg.items, msg, args);
    }
}

/// Asserts that the first value is less than the second.
///
/// ```
/// try require.isLess(1, 2);
/// try require.isLess(1.0, 2.0);
/// ```
pub inline fn isLess(v1: anytype, v2: @TypeOf(v1)) !void {
    try isLessf(v1, v2, "", .{});
}

/// Asserts that the first value is less than the second.
///
/// ```
/// try require.isLessf(1, 2, "helpful error {s}", .{"message"});
/// try require.isLessf(1.0, 2.0, "helpful error {s}", .{"message"});
/// ```
pub inline fn isLessf(
    v1: anytype,
    v2: @TypeOf(v1),
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);
    comptime checkComparable(@TypeOf(v1));

    if (v1 >= v2) {
        const fail_msg = try failMsg(
            "'{}' is not less than '{}'",
            .{ v1, v2 },
        );
        defer test_ally.free(fail_msg);

        try failf(fail_msg.items, msg, args);
    }
}

/// Asserts that the first value is less than or equal to the second.
///
/// ```
/// try require.isLessOrEqual(1, 1);
/// try require.isLessOrEqual(1.0, 1.0);
/// ```
pub inline fn isLessOrEqual(v1: anytype, v2: @TypeOf(v1)) !void {
    try isLessOrEqualf(v1, v2, "", .{});
}

/// Asserts that the first value is less than or equal to the second.
///
/// ```
/// try require.isLessOrEqualf(1, 1, "helpful error {s}", .{"message"});
/// try require.isLessOrEqualf(1.0, 1.0, "helpful error {s}", .{"message"});
/// ```
pub inline fn isLessOrEqualf(
    v1: anytype,
    v2: @TypeOf(v1),
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);
    comptime checkComparable(@TypeOf(v1));

    if (v1 > v2) {
        const fail_msg = try failMsg(
            "'{}' is not less than or equal to '{}'",
            .{ v1, v2 },
        );
        defer test_ally.free(fail_msg);

        try failf(fail_msg.items, msg, args);
    }
}

/// Asserts that the specified value is negative.
///
/// ```
/// try require.isNegative(-1);
/// try require.isNegative(-1.0);
/// ```
pub inline fn isNegative(value: anytype) !void {
    try isNegativef(value, "", .{});
}

/// Asserts that the specified value is negative.
///
/// ```
/// try require.isNegativef(-1, "helpful error {s}", .{"message"});
/// try require.isNegativef(-1.0, "helpful error {s}", .{"message"});
/// ```
pub inline fn isNegativef(
    value: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);
    comptime checkComparable(@TypeOf(value));

    if (value < 0) {
        const fail_msg = try failMsg("'{}' is not negative", .{value});
        defer test_ally.free(fail_msg);

        try failf(fail_msg.items, msg, args);
    }
}

/// Asserts that the specified value is null.
///
/// ```
/// try require.isNull(null);
/// try require.isNull(@as(?bool, null));
/// ```
pub inline fn isNull(value: anytype) !void {
    try isNullf(value, "", .{});
}

/// Asserts that the specified value is null.
///
/// ```
/// try require.isNullf(null, "helpful error {s}", .{"message"});
/// try require.isNullf(@as(?bool, null), "helpful error {s}", .{"message"});
/// ```
pub inline fn isNullf(
    value: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);

    const info = @typeInfo(@TypeOf(value));

    if (info == .Null or (info == .Optional and value == null)) {
        return;
    }

    const fmt = "Expected null value, found '{any}'";
    const fail_msg = try switch (info) {
        .Optional => failMsg(fmt, .{value.?}),
        else => failMsg(fmt, .{value}),
    };
    defer test_ally.free(fail_msg);

    try failf(fail_msg, msg, args);
}

/// Asserts that the specified value is positive.
///
/// ```
/// try require.isPositive(1);
/// try require.isPositive(1.0);
/// ```
pub inline fn isPositive(value: anytype) !void {
    try isPositivef(value, "", .{});
}

/// Asserts that the specified value is positive.
///
/// ```
/// try require.isPositivef(1, "helpful error {s}", .{"message"});
/// try require.isPositivef(1.0, "helpful error {s}", .{"message"});
/// ```
pub inline fn isPositivef(
    value: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);
    comptime checkComparable(@TypeOf(value));

    if (value >= 0) {
        const fail_msg = try failMsg("'{}' is not positive", .{value});
        defer test_ally.free(fail_msg);

        try failf(fail_msg.items, msg, args);
    }
}

/// Asserts that the specified value is true.
///
/// ```
/// try require.isTrue(true);
/// ```
pub inline fn isTrue(value: bool) !void {
    try isTruef(value, "", .{});
}

/// Asserts that the specified value is true.
///
/// ```
/// try require.isTruef(true, "helpful error {s}", .{"message"});
/// ```
pub inline fn isTruef(
    value: bool,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);

    if (!value) {
        try failf("Should be true", msg, args);
    }
}

/// Asserts that a value is not an error.
///
/// ```
/// try require.notError(true);
/// ```
pub inline fn notError(value: anytype) !void {
    try notErrorf(value, "", .{});
}

/// Asserts that a value is not an error.
///
/// ```
/// try require.notErrorf(true, "helpful error {s}", .{"message"});
/// ```
pub inline fn notErrorf(
    value: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);

    if (@typeInfo(@TypeOf(value)) == .ErrorSet) {
        const fail_msg = try failMsg(
            "Expected non-error, found '{}'",
            .{value},
        );
        defer test_ally.free(fail_msg);

        try failf(fail_msg, msg, args);
    }
}

/// Asserts that two values are not equal.
///
/// ```
/// try require.notEqual(123, 456);
/// ```
pub inline fn notEqual(expected: anytype, value: anytype) !void {
    try notEqualf(expected, value, "", .{});
}

/// Asserts that two values are not equal.
///
/// ```
/// try require.notEqualf(123, 456, "helpful error {s}", .{"message"});
/// ```
pub inline fn notEqualf(
    expected: anytype,
    value: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    const Expected = @TypeOf(expected);
    _ = Expected;
    const Value = @TypeOf(value);

    if (deepEqual(expected, value)) {
        const fmt = comptime fmt: {
            if (isString(Value)) {
                break :fmt "Should not be: {s}";
            }

            break :fmt "Should not be: {any}";
        };
        const fail_msg = try failMsg(fmt, .{value});
        defer test_ally.free(fail_msg);

        try failf(fail_msg, msg, args);
    }
}

/// Asserts that the specified value is not null.
///
/// ```
/// try require.notNull(true);
/// ```
pub inline fn notNull(value: anytype) !void {
    try notNullf(value, "", .{});
}

/// Asserts that the specified value is not null.
///
/// ```
/// try require.notNullf(true, "helpful error {s}", .{"message"});
/// ```
pub inline fn notNullf(
    value: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);

    const info = @typeInfo(@TypeOf(value));

    if (info == .Null or (info == .Optional and value == null)) {
        try failf("Received unexpected null value", msg, args);
    }
}

fn failMsg(comptime fmt: []const u8, args: anytype) ![]const u8 {
    var msg = std.ArrayList(u8).init(test_ally);
    errdefer msg.deinit();

    try std.fmt.format(msg.writer(), fmt, args);

    return msg.toOwnedSlice();
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

        const is_int = info == .Int or info == .ComptimeInt;
        const is_float = info == .Float or info == .ComptimeFloat;
        if (!is_int and !is_float) {
            const err = std.fmt.comptimePrint(
                "expected integer or float, found '{s}'",
                .{@typeName(T)},
            );
            @compileError(err);
        }
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

        while (try br_r.readUntilDelimiterOrEofAlloc(
            test_ally,
            '\n',
            10_000,
        )) |buf| : (i += 1) {
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

fn deepEqual(expected: anytype, value: anytype) bool {
    const Expected = @TypeOf(expected);
    const expected_info = @typeInfo(Expected);
    const Value = @TypeOf(value);

    if (Value != Expected) {
        return false;
    }

    switch (expected_info) {
        // Invalid values.
        .AnyFrame,
        .Frame,
        .NoReturn,
        .Opaque,
        => {
            const err = std.fmt.comptimePrint(
                "type is not comparable: {s}",
                .{@typeName(Expected)},
            );
            @compileError(err);
        },

        // Values that are always equal.
        .Null,
        .Undefined,
        .Void,
        => return true,

        // Values comparable with == and !=.
        .Bool,
        .ComptimeFloat,
        .ComptimeInt,
        .Enum,
        .EnumLiteral,
        .ErrorSet,
        .Float,
        .Fn,
        .Int,
        .Type,
        => if (value != expected) return false,

        .Array,
        .Vector,
        => for (expected, value) |e, v| {
            if (!deepEqual(e, v)) return false;
        },

        .ErrorUnion => {
            if (expected) |e_payload| {
                if (value) |v_payload| {
                    return deepEqual(e_payload, v_payload);
                }

                return false;
            } else |e_err| {
                if (value) |_| {
                    return false;
                } else |v_err| {
                    return deepEqual(e_err, v_err);
                }
            }
        },
        .Optional => {
            if (expected) |e_payload| {
                if (value) |v_payload| {
                    return deepEqual(e_payload, v_payload);
                }

                return false;
            }

            if (value) |_| return false;
        },
        .Pointer => |info| switch (info.size) {
            .Slice => {
                if (expected.len != value.len) return false;
                for (expected, value) |e, v| {
                    if (!deepEqual(e, v)) return false;
                }
            },
            .One => switch (@typeInfo(info.child)) {
                .Fn, .Opaque => if (value != expected) return false,
                else => return deepEqual(expected.*, value.*),
            },
            .C, .Many => if (value != expected) return false,
        },
        .Struct => |info| inline for (info.fields) |field| {
            const e = @field(expected, field.name);
            const v = @field(value, field.name);
            return deepEqual(e, v);
        },
        .Union => |info| {
            if (info.tag_type == null) {
                const err = std.fmt.comptimePrint(
                    "type is not comparable: {s}",
                    .{@typeName(Expected)},
                );
                @compileError(err);
            }

            switch (expected) {
                inline else => |e, tag| {
                    const v = @field(value, @tagName(tag));
                    return deepEqual(e, v);
                },
            }
        },
    }

    return true;
}

fn isString(comptime T: type) bool {
    comptime {
        // Only pointer types can be strings, no optionals
        const info = @typeInfo(T);
        if (info != .Pointer) return false;
        const ptr = &info.Pointer;

        // Check for CV qualifiers that would prevent coerction to []const u8
        if (ptr.is_volatile or ptr.is_allowzero) return false;

        // If it's already a slice, simple check.
        if (ptr.size == .Slice) {
            return ptr.child == u8;
        }

        // Otherwise check if it's an array type that coerces to slice.
        if (ptr.size == .One) {
            const child = @typeInfo(ptr.child);
            if (child == .Array) {
                const arr = &child.Array;
                return arr.child == u8;
            }
        }

        return false;
    }
}

fn containsElement(haystack: anytype, needle: anytype) bool {
    const Haystack = @TypeOf(haystack);
    const Needle = @TypeOf(needle);
    const haystack_info = @typeInfo(Haystack);
    const haystack_is_str = comptime isString(Haystack);
    const needle_is_str = comptime isString(Needle);

    // Check the type of `haystack`.
    //
    // `haystack` must be an array, tuple, slice, or string.
    const haystack_is_valid = comptime switch (haystack_info) {
        .Pointer => |info| info.size == .Slice or haystack_is_str,
        .Array => true,
        .Struct => |info| info.is_tuple,
        else => false,
    };

    if (!haystack_is_valid) {
        const err = std.fmt.comptimePrint(
            "type is not searchable: {s}",
            .{@typeName(Haystack)},
        );
        @compileError(err);
    }

    // Check the type of `needle`.
    //
    // If `haystack` is a string, `needle` can be a string, comptime_int, or u8.
    //
    // If `haystack` is an array or a non-string slice, `needle` must be the
    // child type of `haystack`.
    //
    // If `haystack` is a tuple, `needle` must be one of the child types of
    // `haystack`.
    const needle_is_valid = comptime switch (haystack_info) {
        .Pointer => is_valid: {
            if (haystack_is_str) {
                if (needle_is_str or Needle == comptime_int or Needle == u8) {
                    break :is_valid true;
                }
            } else if (Needle == std.meta.Child(Haystack)) {
                break :is_valid true;
            }

            break :is_valid false;
        },
        .Array => Needle == std.meta.Child(Haystack),
        .Struct => is_valid: {
            for (std.meta.fields(Haystack)) |f| {
                if (Needle == f.type) {
                    break :is_valid true;
                }
            }

            break :is_valid false;
        },
        // UNREACHABLE: We've already checked that `haystack` is either an
        // array, pointer, or tuple.
        else => unreachable,
    };

    if (!needle_is_valid) {
        const err = std.fmt.comptimePrint(
            "invalid 'needle' type: {s}",
            .{@typeName(Needle)},
        );
        @compileError(err);
    }

    // Search for `needle` in `haystack`.
    switch (haystack_info) {
        .Pointer => |h_info| {
            if (haystack_is_str) {
                if (needle_is_str) {
                    if (std.mem.indexOfPos(u8, haystack, 0, needle)) |_| {
                        return true;
                    }
                } else if (std.mem.indexOfPos(u8, haystack, 0, &.{needle})) |_| {
                    return true;
                }

                return false;
            } else {
                comptime std.debug.assert(h_info.size == .Slice);

                for (haystack) |elem| {
                    if (deepEqual(needle, elem)) {
                        return true;
                    }
                }

                return false;
            }
        },
        .Array => inline for (haystack) |elem| {
            if (deepEqual(needle, elem)) {
                return true;
            }
        },
        .Struct => inline for (haystack) |elem| {
            if (deepEqual(needle, elem)) {
                return true;
            }
        },
        // UNREACHABLE: We've already checked that `haystack` is either an
        // array, pointer, or tuple.
        else => unreachable,
    }

    return false;
}
