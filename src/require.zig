const std = @import("std");

const print = std.debug.print;
const test_ally = std.testing.allocator;

/// Asserts that the specified value is false.
///
/// ```
/// require.isFalse(my_bool);
/// ```
pub fn isFalse(value: bool) !void {
    if (value) {
        return fail("Should be false");
    }
}

/// Asserts that the specified value is false.
///
/// ```
/// require.isFalsef(my_bool, "value is not {}", .{false});
/// ```
pub fn isFalsef(value: bool, comptime msg: []const u8, args: anytype) !void {
    if (value) {
        return failf("Should be false", msg, args);
    }
}

/// Asserts that the specified value is true.
///
/// ```
/// require.isTrue(my_bool);
/// ```
pub fn isTrue(value: bool) !void {
    if (!value) {
        return fail("Should be true");
    }
}

/// Asserts that the specified value is true.
///
/// ```
/// require.isTrue(my_bool, "value is not {}", .{true});
/// ```
pub fn isTruef(value: bool, comptime msg: []const u8, args: anytype) !void {
    if (!value) {
        return failf("Should be true", msg, args);
    }
}

/// Reports a failure.
pub fn fail(fail_msg: []const u8) !void {
    return try failf(fail_msg, "", .{});
}

/// Reports a failure.
pub fn failf(fail_msg: []const u8, comptime msg: []const u8, args: anytype) !void {
    var content = content: {
        var cap: usize = if (msg.len == 0) 2 else 3;
        break :content try std.ArrayList(LabelContent).initCapacity(test_ally, cap);
    };
    defer content.deinit();

    content.appendAssumeCapacity(.{
        .label = "Error",
        .content = fail_msg,
    });

    var formatted_msg = formatted_msg: {
        var formatted_msg = try std.ArrayList(u8).initCapacity(test_ally, msg.len);
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

const LabelContent = struct {
    label: []const u8,
    content: []const u8,
};

fn labelOutput(contents: []const LabelContent) ![]const u8 {
    var longest_label_len: usize = longest_label_len: {
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
        var iml = try indentMessageLines(v.content, longest_label_len);
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
                for (0..longest_label_len + 1) |_| {
                    try output.append(' ');
                }
                try output.append('\t');
            }

            try output.appendSlice(buf);
        }
    }

    return output.toOwnedSlice();
}
