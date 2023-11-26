# Protest

Protest is a set of modules for testing and validating Zig code.

## `require` Module

The `require` module some provides helpful functions to help you write tests.

- Descriptive and easy to read failure descriptions.
- Simplified testing code.
- Requirements can be annotated with a custom message.

```zig
const require = @import("protest").require;

test {
    // Require equality.
    try require.equalf(123, 123, "They should be {s}", .{"equal"});

    // Require inequality.
    try require.notEqualf(123, 456, "They should not be {s}", .{"equal"});

    // Require that `value` is not null.
    try require.notNull(value);

    // Since `value` cannot be null, we can safely unwrap it
    // and validate its payload.
    try require.equal("Foobar", value.?);
}
```
