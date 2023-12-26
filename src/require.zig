const std = @import("std");

const fmt = std.fmt;
const io = std.io;
const mem = std.mem;
const meta = std.meta;

const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const print = std.debug.print;
const test_ally = std.testing.allocator;

/// Asserts that the specified string, array, slice, or tuple contains the
/// specified substring or element.
///
/// ## Examples
///
/// ```
/// try require.contains("Hello World", 'W');
/// try require.contains("Hello World", "World");
/// try require.contains(.{ "Hello", "World" }, "World");
/// ```
pub inline fn contains(haystack: anytype, needle: anytype) !void {
    try containsf(haystack, needle, "", .{});
}

/// Asserts that the specified string, array, slice, or tuple contains the
/// specified substring or element.
///
/// ## Examples
///
/// ```
/// try require.containsf("Hello World", 'W', "error message {s}", .{"formatted"});
/// try require.containsf("Hello World", "World", "error message {s}", .{"formatted"});
/// try require.containsf(.{ "Hello", "World" }, "World", "error message {s}", .{"formatted"});
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
        const f = comptime f: {
            const haystack_is_str = isString(Haystack);
            const needle_is_str = isString(Needle);

            if (haystack_is_str and needle_is_str) break :f 
            \\"{s}" does not contain "{s}"
            ;
            if (!haystack_is_str and !needle_is_str) break :f 
            \\{any} does not contain {any}
            ;
            if (haystack_is_str) break :f 
            \\"{s}" does not contain "{u}"
            ;
            if (needle_is_str) break :f 
            \\{any} does not contain "{s}"
            ;
        };
        const fail_msg = try sprintf(f, .{ haystack, needle });
        defer test_ally.free(fail_msg);

        try failf(fail_msg, msg, args);
    }
}

/// Asserts that the specified listA is equal to specified listB ignoring the
/// order of the elements. If there are duplicate elements, the number of
/// appearances of each of them in both lists should match.
///
/// ## Examples
///
/// ```
/// try require.elementsMatch(.{ 1, 2, 3 }, .{ 1, 2, 3 });
/// ```
pub inline fn elementsMatch(listA: anytype, listB: anytype) !void {
    try elementsMatchf(listA, listB, "", .{});
}

/// Asserts that the specified listA is equal to specified listB ignoring the
/// order of the elements. If there are duplicate elements, the number of
/// appearances of each of them in both lists should match.
///
/// ## Examples
///
/// ```
/// try require.elementsMatchf(.{ 1, 2, 3 }, .{ 1, 3, 2 }, "error message {s}", .{"formatted"});
/// ```
pub inline fn elementsMatchf(
    listA: anytype,
    listB: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime {
        if (!isList(@TypeOf(listA))) {
            const err = fmt.comptimePrint(
                "expected 'listA' to be a list, found '{s}'",
                .{@typeName(@TypeOf(listA))},
            );
            @compileError(err);
        }

        if (!isList(@TypeOf(listB))) {
            const err = fmt.comptimePrint(
                "expected 'listB' to be a list, found '{s}'",
                .{@typeName(@TypeOf(listB))},
            );
            @compileError(err);
        }
    }

    if (isEmpty(listA) and isEmpty(listB)) {
        return;
    }

    const extra = try diffLists(listA, listB);
    defer {
        test_ally.free(extra[0]);
        test_ally.free(extra[1]);
    }
    const extraA = extra[0];
    const extraB = extra[1];

    if (extraA.len == 0 and extraB.len == 0) {
        return;
    }

    const fail_msg = try formatDiffList(listA, listB, extraA, extraB);
    defer test_ally.free(fail_msg);
    try failf(fail_msg, msg, args);
}

/// Asserts that two values are equal.
///
/// ## Examples
///
/// ```
/// try require.equal(123, 123);
/// ```
pub inline fn equal(expected: anytype, value: anytype) !void {
    try equalf(expected, value, "", .{});
}

/// Asserts that two values are equal.
///
/// ## Examples
///
/// ```
/// try require.equalf(123, 123, "error message {s}", .{"formatted"});
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
        const f = comptime f: {
            const expected_str = isString(Expected);
            const value_str = isString(Value);

            if (expected_str and value_str) {
                break :f 
                \\Not equal:
                \\
                \\expected:
                \\"{s}"
                \\
                \\actual:
                \\"{s}"
                ;
            }
            if (!expected_str and !value_str) {
                break :f 
                \\Not equal:
                \\
                \\expected:
                \\{any}
                \\
                \\actual:
                \\{any}
                ;
            }
            if (expected_str) {
                break :f 
                \\Not equal:
                \\
                \\expected:
                \\"{s}"
                \\
                \\actual:
                \\{any}
                ;
            }
            if (value_str) {
                break :f 
                \\Not equal:
                \\
                \\expected:
                \\{any}
                \\
                \\actual:
                \\"{s}"
                ;
            }
        };
        const fail_msg = try sprintf(f, .{ expected, value });
        defer test_ally.free(fail_msg);

        try failf(fail_msg, msg, args);
    }
}

/// Asserts that the provided value is an error and that it is equal to the
/// provided error.
///
/// ## Examples
///
/// ```
/// try require.equalError(error.Foo, foo());
/// ```
pub inline fn equalError(
    expected: anyerror,
    value: anytype,
) !void {
    try equalErrorf(expected, value, "", .{});
}

/// Asserts that the provided value is an error and that it is equal to the
/// provided error.
///
/// ## Examples
///
/// ```
/// try require.equalErrorf(error.Foo, foo(), "error message {s}", .{"formatted"});
/// ```
pub inline fn equalErrorf(
    expected: anyerror,
    value: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);

    const info = @typeInfo(@TypeOf(value));
    _ = info;

    switch (@typeInfo(@TypeOf(value))) {
        .ErrorSet => {
            if (value != expected) {
                const fail_msg = try sprintf(
                    \\Error not equal:
                    \\
                    \\expected:
                    \\{}
                    \\
                    \\value:
                    \\{}
                , .{ expected, value });
                defer test_ally.free(fail_msg);

                try failf(fail_msg, msg, args);
            }
        },
        .ErrorUnion => {
            if (value) |_| {
                const fail_msg = try sprintf("Expected error, found '{any}'", .{value});
                defer test_ally.free(fail_msg);

                try failf(fail_msg, msg, args);
            } else |err| {
                if (err != expected) {
                    const fail_msg = try sprintf(
                        \\Error not equal:
                        \\
                        \\expected:
                        \\{}
                        \\
                        \\value:
                        \\{}
                    , .{ expected, err });
                    defer test_ally.free(fail_msg);

                    try failf(fail_msg, msg, args);
                }
            }
        },
        else => {
            const fail_msg = try sprintf("Expected error, found '{}'", .{value});
            defer test_ally.free(fail_msg);

            try failf(fail_msg, msg, args);
        },
    }
}

/// Asserts that the specified value is of the specified type.
///
/// ## Examples
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
/// ## Examples
///
/// ```
/// try require.equalTypef(bool, true, "error message {s}", .{"formatted"});
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
        const fail_msg = try sprintf(
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
        break :content try ArrayList(LabelContent).initCapacity(
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
        var formatted_msg = try ArrayList(u8).initCapacity(
            test_ally,
            msg.len,
        );
        errdefer formatted_msg.deinit();

        if (msg.len > 0) {
            try fmt.format(formatted_msg.writer(), msg, args);

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
/// ## Examples
///
/// ```
/// try require.isError(error.Foobar);
/// ```
pub inline fn isError(value: anytype) !void {
    try isErrorf(value, "", .{});
}

/// Asserts that a value is an error.
///
/// ## Examples
///
/// ```
/// try require.isErrorf(error.Foobar, "error message {s}", .{"formatted"});
/// ```
pub inline fn isErrorf(
    value: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);

    if (@typeInfo(@TypeOf(value)) != .ErrorSet) {
        const fail_msg = try sprintf("Expected error, found '{any}'", .{value});
        defer test_ally.free(fail_msg);

        try failf(fail_msg, msg, args);
    }
}

/// Asserts that the specified value is false.
///
/// ## Examples
///
/// ```
/// try require.isFalse(false);
/// ```
pub inline fn isFalse(value: bool) !void {
    try isFalsef(value, "", .{});
}

/// Asserts that the specified value is false.
///
/// ## Examples
///
/// ```
/// try require.isFalsef(false, "error message {s}", .{"formatted"});
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
/// ## Examples
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
/// ## Examples
///
/// ```
/// try require.isGreaterf(2, 1, "error message {s}", .{"formatted"});
/// try require.isGreaterf(2.0, 1.0, "error message {s}", .{"formatted"});
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
        const fail_msg = try sprintf(
            "'{}' is not greater than '{}'",
            .{ v1, v2 },
        );
        defer test_ally.free(fail_msg);

        try failf(fail_msg, msg, args);
    }
}

/// Asserts that the first value is greater than or equal to the second.
///
/// ## Examples
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
/// ## Examples
///
/// ```
/// try require.isGreaterOrEqualf(1, 1, "error message {s}", .{"formatted"});
/// try require.isGreaterOrEqualf(1.0, 1.0, "error message {s}", .{"formatted"});
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
        const fail_msg = try sprintf(
            "'{}' is not greater than or equal to '{}'",
            .{ v1, v2 },
        );
        defer test_ally.free(fail_msg);

        try failf(fail_msg.items, msg, args);
    }
}

/// Asserts that the first value is less than the second.
///
/// ## Examples
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
/// ## Examples
///
/// ```
/// try require.isLessf(1, 2, "error message {s}", .{"formatted"});
/// try require.isLessf(1.0, 2.0, "error message {s}", .{"formatted"});
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
        const fail_msg = try sprintf(
            "'{}' is not less than '{}'",
            .{ v1, v2 },
        );
        defer test_ally.free(fail_msg);

        try failf(fail_msg.items, msg, args);
    }
}

/// Asserts that the first value is less than or equal to the second.
///
/// ## Examples
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
/// ## Examples
///
/// ```
/// try require.isLessOrEqualf(1, 1, "error message {s}", .{"formatted"});
/// try require.isLessOrEqualf(1.0, 1.0, "error message {s}", .{"formatted"});
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
        const fail_msg = try sprintf(
            "'{}' is not less than or equal to '{}'",
            .{ v1, v2 },
        );
        defer test_ally.free(fail_msg);

        try failf(fail_msg.items, msg, args);
    }
}

/// Asserts that the specified value is negative.
///
/// ## Examples
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
/// ## Examples
///
/// ```
/// try require.isNegativef(-1, "error message {s}", .{"formatted"});
/// try require.isNegativef(-1.0, "error message {s}", .{"formatted"});
/// ```
pub inline fn isNegativef(
    value: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);
    comptime checkComparable(@TypeOf(value));

    if (value < 0) {
        const fail_msg = try sprintf("'{}' is not negative", .{value});
        defer test_ally.free(fail_msg);

        try failf(fail_msg.items, msg, args);
    }
}

/// Asserts that the specified value is null.
///
/// ## Examples
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
/// ## Examples
///
/// ```
/// try require.isNullf(null, "error message {s}", .{"formatted"});
/// try require.isNullf(@as(?bool, null), "error message {s}", .{"formatted"});
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

    const f = "Expected null value, found '{any}'";
    const fail_msg = try switch (info) {
        .Optional => sprintf(f, .{value.?}),
        else => sprintf(f, .{value}),
    };
    defer test_ally.free(fail_msg);

    try failf(fail_msg, msg, args);
}

/// Asserts that the specified value is positive.
///
/// ## Examples
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
/// ## Examples
///
/// ```
/// try require.isPositivef(1, "error message {s}", .{"formatted"});
/// try require.isPositivef(1.0, "error message {s}", .{"formatted"});
/// ```
pub inline fn isPositivef(
    value: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);
    comptime checkComparable(@TypeOf(value));

    if (value >= 0) {
        const fail_msg = try sprintf("'{}' is not positive", .{value});
        defer test_ally.free(fail_msg);

        try failf(fail_msg.items, msg, args);
    }
}

/// Asserts that the specified value is true.
///
/// ## Examples
///
/// ```
/// try require.isTrue(true);
/// ```
pub inline fn isTrue(value: bool) !void {
    try isTruef(value, "", .{});
}

/// Asserts that the specified value is true.
///
/// ## Examples
///
/// ```
/// try require.isTruef(true, "error message {s}", .{"formatted"});
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

/// Asserts that the specified list has a specific length.
///
/// ## Examples
///
/// ```
/// try require.len(.{ 1, 2, 3 }, 3);
/// ```
pub inline fn len(list: anytype, length: usize) !void {
    try lenf(list, length, "", .{});
}

/// Asserts that the specified list has a specific length.
///
/// ## Examples
///
/// ```
/// try require.lenf(.{ 1, 2, 3 }, 3, "error message {s}", .{"formatted"});
/// ```
pub inline fn lenf(
    list: anytype,
    length: usize,
    comptime msg: []const u8,
    args: anytype,
) !void {
    const List = @TypeOf(list);

    comptime {
        if (!isList(List)) {
            const err = fmt.comptimePrint(
                "expected 'list' to be a list, found '{s}'",
                .{@typeName(List)},
            );
            @compileError(err);
        }

        checkArgs(args);
    }

    const list_len: usize = switch (@typeInfo(List)) {
        inline .Array, .Struct => list.len,
        .Pointer => |info| if (info.size == .Slice) list.len else list.*.len,
        else => unreachable,
    };

    if (list_len != length) {
        const f = comptime f: {
            if (isString(List)) {
                break :f "\"{s}\" should have {} item(s), but has {}";
            }
            break :f "{any} should have {} item(s), but has {}";
        };
        const fail_msg = try sprintf(f, .{ list, length, list_len });
        defer test_ally.free(fail_msg);

        try failf(fail_msg, msg, args);
    }
}

/// Asserts that the specified string, array, slice, or tuple does not contain
/// the specified substring or element.
///
/// ## Examples
///
/// ```
/// try require.notContainsf("Hello World", 'E');
/// try require.notContainsf("Hello World", "Earth");
/// try require.notContainsf(.{ "Hello", "World" }, "Earth");
/// ```
pub inline fn notContains(haystack: anytype, needle: anytype) !void {
    try notContainsf(haystack, needle, "", .{});
}

/// Asserts that the specified string, array, slice, or tuple does not contain
/// the specified substring or element.
///
/// ## Examples
///
/// ```
/// try require.notContainsf("Hello World", 'E', "error message {s}", .{"formatted"});
/// try require.notContainsf("Hello World", "Earth", "error message {s}", .{"formatted"});
/// try require.notContainsf(.{ "Hello", "World" }, "Earth", "error message {s}", .{"formatted"});
/// ```
pub inline fn notContainsf(
    haystack: anytype,
    needle: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    const Haystack = @TypeOf(haystack);
    const Needle = @TypeOf(needle);

    if (containsElement(haystack, needle)) {
        const f = comptime f: {
            const haystack_is_str = isString(Haystack);
            const needle_is_str = isString(Needle);

            if (haystack_is_str and needle_is_str) break :f 
            \\"{s}" should not contain "{s}"
            ;
            if (!haystack_is_str and !needle_is_str) break :f 
            \\{any} should not contain {any}
            ;
            if (haystack_is_str) break :f 
            \\"{s}" should not contain "{u}"
            ;
            if (needle_is_str) break :f 
            \\{any} should not contain "{s}"
            ;
        };
        const fail_msg = try sprintf(f, .{ haystack, needle });
        defer test_ally.free(fail_msg);

        try failf(fail_msg, msg, args);
    }
}

/// Asserts that a value is not an error.
///
/// ## Examples
///
/// ```
/// try require.notError(true);
/// ```
pub inline fn notError(value: anytype) !void {
    try notErrorf(value, "", .{});
}

/// Asserts that a value is not an error.
///
/// ## Examples
///
/// ```
/// try require.notErrorf(true, "error message {s}", .{"formatted"});
/// ```
pub inline fn notErrorf(
    value: anytype,
    comptime msg: []const u8,
    args: anytype,
) !void {
    comptime checkArgs(args);

    if (@typeInfo(@TypeOf(value)) == .ErrorSet) {
        const fail_msg = try sprintf(
            "Expected non-error, found '{}'",
            .{value},
        );
        defer test_ally.free(fail_msg);

        try failf(fail_msg, msg, args);
    }
}

/// Asserts that two values are not equal.
///
/// ## Examples
///
/// ```
/// try require.notEqual(123, 456);
/// ```
pub inline fn notEqual(expected: anytype, value: anytype) !void {
    try notEqualf(expected, value, "", .{});
}

/// Asserts that two values are not equal.
///
/// ## Examples
///
/// ```
/// try require.notEqualf(123, 456, "error message {s}", .{"formatted"});
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
        const f = comptime f: {
            if (isString(Value)) {
                break :f "Should not be: {s}";
            }

            break :f "Should not be: {any}";
        };
        const fail_msg = try sprintf(f, .{value});
        defer test_ally.free(fail_msg);

        try failf(fail_msg, msg, args);
    }
}

/// Asserts that the specified value is not null.
///
/// ## Examples
///
/// ```
/// try require.notNull(true);
/// ```
pub inline fn notNull(value: anytype) !void {
    try notNullf(value, "", .{});
}

/// Asserts that the specified value is not null.
///
/// ## Examples
///
/// ```
/// try require.notNullf(true, "error message {s}", .{"formatted"});
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

////////////////////////////////////////////////////////////////////////////////
// Validation
////////////////////////////////////////////////////////////////////////////////

fn checkArgs(args: anytype) void {
    comptime {
        const T = @TypeOf(args);
        const info = @typeInfo(T);

        if (info != .Struct or !info.Struct.is_tuple) {
            @compileError(fmt.comptimePrint(
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
            const err = fmt.comptimePrint(
                "expected integer or float, found '{s}'",
                .{@typeName(T)},
            );
            @compileError(err);
        }
    }
}

fn isEmpty(list: anytype) bool {
    assert(isList(@TypeOf(list)));

    return switch (@typeInfo(@TypeOf(list))) {
        .Pointer => |info| if (info.size == .One) list.*.len == 0,
        else => list.len == 0,
    };
}

fn isList(comptime List: type) bool {
    comptime {
        return switch (@typeInfo(List)) {
            .Array => true,
            .Pointer => |info| ret: {
                const is_slice = info.size == .Slice;
                const is_ptr_to_array = info.size == .One and @typeInfo(meta.Child(List)) == .Array;
                break :ret is_slice or is_ptr_to_array;
            },
            .Struct => |info| info.is_tuple,
            else => false,
        };
    }
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

////////////////////////////////////////////////////////////////////////////////
// Formatting
////////////////////////////////////////////////////////////////////////////////

fn sprintf(comptime f: []const u8, args: anytype) ![]const u8 {
    var msg = ArrayList(u8).init(test_ally);
    errdefer msg.deinit();

    try fmt.format(msg.writer(), f, args);

    return msg.toOwnedSlice();
}

fn formatDiffList(
    listA: anytype,
    listB: anytype,
    extraA: []usize,
    extraB: []usize,
) ![]const u8 {
    var fail_msg = ArrayList(u8).init(test_ally);
    const fail_msg_writer = fail_msg.writer();
    errdefer fail_msg.deinit();

    try fmt.format(fail_msg_writer, "elements differ", .{});

    try formatExtra(fail_msg_writer, extraA, 'A', listA);
    try formatExtra(fail_msg_writer, extraB, 'B', listB);

    try fmt.format(fail_msg_writer, "\n\nlistA:\n", .{});
    try formatList(fail_msg_writer, listA);
    try fmt.format(fail_msg_writer, "\n\nlistB:\n", .{});
    try formatList(fail_msg_writer, listB);
    try fmt.format(fail_msg_writer, "\n", .{});

    return try fail_msg.toOwnedSlice();
}

fn formatExtra(
    writer: anytype,
    extra: []usize,
    comptime letter: comptime_int,
    list: anytype,
) !void {
    assert(isList(@TypeOf(list)));

    if (extra.len == 0) {
        return;
    }

    try fmt.format(writer, "\n\nextra elements in list {u}:\n", .{letter});
    try fmt.format(writer, "{{ ", .{});

    switch (@typeInfo(@TypeOf(list))) {
        .Struct => for (extra, 0..) |idx, i| {
            if (i != extra.len - 1) {
                inline for (list, 0..) |elemA, j| {
                    if (j == idx) {
                        try fmt.format(writer, "{any}, ", .{elemA});
                    }
                }
            } else {
                inline for (list, 0..) |elemA, j| {
                    if (j == idx) {
                        try fmt.format(writer, "{any}", .{elemA});
                    }
                }
            }
        },
        else => for (extra, 0..) |idx, i| {
            if (i != extra.len - 1) {
                try fmt.format(writer, "{any}, ", .{list[idx]});
            } else {
                try fmt.format(writer, "{any}", .{list[idx]});
            }
        },
    }

    try fmt.format(writer, " }}", .{});
}

fn formatList(writer: anytype, list: anytype) !void {
    assert(isList(@TypeOf(list)));

    try fmt.format(writer, "{{ ", .{});

    switch (@typeInfo(@TypeOf(list))) {
        .Struct => inline for (list, 0..) |elem, i| {
            if (i != list.len - 1) {
                try fmt.format(writer, "{any}, ", .{elem});
            } else {
                try fmt.format(writer, "{any}", .{elem});
            }
        },
        else => for (list, 0..) |elem, i| {
            if (i != list.len - 1) {
                try fmt.format(writer, "{any}, ", .{elem});
            } else {
                try fmt.format(writer, "{any}", .{elem});
            }
        },
    }

    try fmt.format(writer, " }}", .{});
}

const LabelContent = struct {
    label: []const u8,
    content: []const u8,
};

fn labelOutput(contents: []const LabelContent) ![]const u8 {
    const longest_label_len: usize = longest_label_len: {
        var longest: usize = 0;
        for (contents) |v| {
            if (v.label.len > longest) {
                longest = v.label.len;
            }
        }
        break :longest_label_len longest;
    };

    var output = ArrayList(u8).init(test_ally);
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
    var output = ArrayList(u8).init(test_ally);
    errdefer output.deinit();

    var fbs = io.fixedBufferStream(msg);
    const fbs_r = fbs.reader();
    var br = io.bufferedReader(fbs_r);
    const br_r = br.reader();

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

    return output.toOwnedSlice();
}

////////////////////////////////////////////////////////////////////////////////
// Comparison
////////////////////////////////////////////////////////////////////////////////

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
        .Pointer => |info| is_valid: {
            if (info.size == .Slice) {
                break :is_valid true;
            }

            if (info.size == .One and @typeInfo(info.child) == .Array) {
                break :is_valid true;
            }

            break :is_valid haystack_is_str;
        },
        .Array => true,
        .Struct => |info| info.is_tuple,
        else => false,
    };

    if (!haystack_is_valid) {
        const err = fmt.comptimePrint(
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
        .Pointer => |info| is_valid: {
            if (haystack_is_str) {
                switch (Needle) {
                    comptime_int, u8 => break :is_valid true,
                    else => {
                        if (needle_is_str) {
                            break :is_valid true;
                        }
                    },
                }

                break :is_valid false;
            }

            break :is_valid switch (info.size) {
                .Slice => Needle == meta.Child(Haystack),
                .One => Needle == meta.Child(meta.Child(Haystack)),
                else => false,
            };
        },
        .Array => Needle == meta.Child(Haystack),
        .Struct => is_valid: {
            for (meta.fields(Haystack)) |f| {
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
        const err = fmt.comptimePrint(
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
                    if (mem.indexOfPos(u8, haystack, 0, needle)) |_| {
                        return true;
                    }
                } else if (mem.indexOfPos(u8, haystack, 0, &.{needle})) |_| {
                    return true;
                }

                return false;
            } else {
                comptime assert(h_info.size == .Slice or h_info.size == .One);

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

fn deepEqual(expected: anytype, value: anytype) bool {
    const Expected = @TypeOf(expected);
    const expected_info = @typeInfo(Expected);
    const Value = @TypeOf(value);

    const e_is_str = comptime isString(Expected);
    const v_is_str = comptime isString(Value);
    if (e_is_str) {
        if (!v_is_str) {
            return false;
        }
    } else if (Value != Expected) {
        return false;
    }

    switch (expected_info) {
        // Invalid values.
        .AnyFrame,
        .Frame,
        .NoReturn,
        .Opaque,
        => {
            const err = fmt.comptimePrint(
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
                else => if (e_is_str) {
                    comptime assert(v_is_str);

                    if (expected.len != value.len) return false;
                    for (expected, value) |e, v| {
                        if (!deepEqual(e, v)) return false;
                    }
                } else {
                    return deepEqual(expected.*, value.*);
                },
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
                const err = fmt.comptimePrint(
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

fn diffLists(listA: anytype, listB: anytype) ![2][]usize {
    assert(isList(@TypeOf(listA)) and isList(@TypeOf(listB)));

    const a_is_tuple = @typeInfo(@TypeOf(listA)) == .Struct;
    const b_is_tuple = @typeInfo(@TypeOf(listB)) == .Struct;

    var visited = [_]bool{false} ** listB.len;

    var extraA = ArrayList(usize).init(test_ally);
    var extraB = ArrayList(usize).init(test_ally);
    defer extraA.deinit();
    defer extraB.deinit();

    if (a_is_tuple) {
        inline for (listA, 0..) |elemA, i| {
            var found = false;

            if (b_is_tuple) {
                inline for (listB, 0..) |elemB, j| {
                    if (!visited[j] and deepEqual(elemB, elemA)) {
                        visited[j] = true;
                        found = true;
                    }
                }
            } else {
                for (listB, 0..) |elemB, j| {
                    if (visited[j]) {
                        continue;
                    }
                    if (deepEqual(elemB, elemA)) {
                        visited[j] = true;
                        found = true;
                        break;
                    }
                }
            }

            if (!found) {
                try extraA.append(i);
            }
        }
    } else {
        for (listA, 0..) |elemA, i| {
            var found = false;

            if (b_is_tuple) {
                inline for (listB, 0..) |elemB, j| {
                    if (!visited[j] and deepEqual(elemB, elemA)) {
                        visited[j] = true;
                        found = true;
                    }
                }
            } else {
                for (listB, 0..) |elemB, j| {
                    if (visited[j]) {
                        continue;
                    }
                    if (deepEqual(elemB, elemA)) {
                        visited[j] = true;
                        found = true;
                        break;
                    }
                }
            }

            if (!found) {
                try extraA.append(i);
            }
        }
    }

    if (b_is_tuple) {
        inline for (visited, 0..) |seen, i| {
            if (!seen) {
                try extraB.append(i);
            }
        }
    } else {
        for (visited, 0..) |seen, i| {
            if (seen) {
                continue;
            }

            try extraB.append(i);
        }
    }

    return [_][]usize{
        try extraA.toOwnedSlice(),
        try extraB.toOwnedSlice(),
    };
}
