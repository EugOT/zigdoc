const std = @import("std");

pub const ParsedArgs = struct {
    help_file: []const u8,
    output_file: []const u8,
};

pub const ParseError = error{InvalidArgs};

/// Parse the positional arguments for `gen_readme`. The caller supplies
/// `prog_name` (typically `argv[0]`) and `rest` (the positionals after
/// the program name). Exactly two positionals are required; any other
/// arity returns `error.InvalidArgs` and writes a usage line to `usage`.
/// Returns `error.OutOfMemory` if the usage buffer cannot grow.
pub fn parseArgs(
    usage_gpa: std.mem.Allocator,
    prog_name: []const u8,
    rest: []const []const u8,
    usage: *std.ArrayList(u8),
) (ParseError || error{OutOfMemory})!ParsedArgs {
    if (rest.len != 2) {
        try usage.print(usage_gpa, "Usage: {s} <help-file> <output-file>\n", .{prog_name});
        return error.InvalidArgs;
    }
    return .{
        .help_file = rest[0],
        .output_file = rest[1],
    };
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var iter = try init.minimal.args.iterateAllocator(allocator);
    defer iter.deinit();

    // argv[0] — captured for accurate usage messages.
    const prog_name_raw = iter.next() orelse return error.InvalidArgs;
    const prog_name = try allocator.dupe(u8, prog_name_raw);
    defer allocator.free(prog_name);

    // Collect remaining positionals so we can reject extras (>2) explicitly
    // instead of silently ignoring trailing arguments.
    var positionals: std.ArrayList([]const u8) = .empty;
    defer {
        for (positionals.items) |p| allocator.free(p);
        positionals.deinit(allocator);
    }
    while (iter.next()) |arg| {
        const owned = try allocator.dupe(u8, arg);
        try positionals.append(allocator, owned);
    }

    var usage_buf: std.ArrayList(u8) = .empty;
    defer usage_buf.deinit(allocator);
    const parsed = parseArgs(allocator, prog_name, positionals.items, &usage_buf) catch |err| {
        std.debug.print("{s}", .{usage_buf.items});
        return err;
    };

    const cwd = std.Io.Dir.cwd();
    const help_content = try cwd.readFileAlloc(io, parsed.help_file, allocator, .limited(1024 * 1024));
    defer allocator.free(help_content);

    const readme = try std.fmt.allocPrint(allocator,
        \\# zigdoc
        \\
        \\A command-line tool to view documentation for Zig standard library symbols.
        \\
        \\## Installation
        \\
        \\```bash
        \\zig build install -Doptimize=ReleaseFast --prefix $HOME/.local
        \\```
        \\
        \\## Usage
        \\
        \\```
        \\{s}```
        \\
        \\## Project Initialization
        \\
        \\`zigdoc @init` scaffolds a minimal Zig project with `AGENTS.md`
        \\plus `build.zig` and `build.zig.zon` configured for `ziglint`.
        \\
        \\```bash
        \\mkdir my-project && cd my-project
        \\zigdoc @init
        \\```
        \\
        \\## Examples
        \\
        \\```bash
        \\# Standard library symbols
        \\zigdoc std.ArrayList
        \\zigdoc std.mem.Allocator
        \\zigdoc std.http.Server
        \\
        \\# Imported modules from build.zig
        \\zigdoc zeit.timezone.Posix
        \\```
        \\
        \\## Features
        \\
        \\- View documentation for any public symbol in the Zig standard library
        \\- Access documentation for imported modules from your build.zig
        \\- Shows symbol location, category, and signature
        \\- Displays doc comments and members
        \\- Follows aliases to implementation
        \\
    , .{help_content});
    defer allocator.free(readme);

    try cwd.writeFile(io, .{ .sub_path = parsed.output_file, .data = readme });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "parseArgs accepts exactly two positionals" {
    const t = std.testing;
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(t.allocator);
    const args = [_][]const u8{ "doc/help.txt", "README.md" };
    const parsed = try parseArgs(t.allocator, "gen_readme", &args, &buf);
    try t.expectEqualStrings("doc/help.txt", parsed.help_file);
    try t.expectEqualStrings("README.md", parsed.output_file);
    try t.expectEqual(@as(usize, 0), buf.items.len);
}

test "parseArgs rejects zero positionals and uses prog_name in usage" {
    const t = std.testing;
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(t.allocator);
    const args: [0][]const u8 = .{};
    try t.expectError(error.InvalidArgs, parseArgs(t.allocator, "custom-prog", &args, &buf));
    try t.expect(std.mem.indexOf(u8, buf.items, "custom-prog") != null);
    try t.expect(std.mem.indexOf(u8, buf.items, "<help-file>") != null);
    try t.expect(std.mem.indexOf(u8, buf.items, "<output-file>") != null);
}

test "parseArgs rejects single positional" {
    const t = std.testing;
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(t.allocator);
    const args = [_][]const u8{"only-help.txt"};
    try t.expectError(error.InvalidArgs, parseArgs(t.allocator, "gen_readme", &args, &buf));
}

test "parseArgs rejects more than two positionals" {
    const t = std.testing;
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(t.allocator);
    const args = [_][]const u8{ "help.txt", "README.md", "extra-arg" };
    try t.expectError(error.InvalidArgs, parseArgs(t.allocator, "gen_readme", &args, &buf));
}

test "parseArgs rejects four positionals" {
    const t = std.testing;
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(t.allocator);
    const args = [_][]const u8{ "a", "b", "c", "d" };
    try t.expectError(error.InvalidArgs, parseArgs(t.allocator, "gen_readme", &args, &buf));
}
