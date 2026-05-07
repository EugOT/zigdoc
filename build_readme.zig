const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var iter = try init.minimal.args.iterateAllocator(allocator);
    defer iter.deinit();

    _ = iter.next() orelse return error.InvalidArgs; // program name
    const help_file = iter.next() orelse {
        std.debug.print("Usage: gen_readme <help-file> <output-file>\n", .{});
        return error.InvalidArgs;
    };
    const output_file = iter.next() orelse {
        std.debug.print("Usage: gen_readme <help-file> <output-file>\n", .{});
        return error.InvalidArgs;
    };

    const cwd = std.Io.Dir.cwd();
    const help_content = try cwd.readFileAlloc(io, help_file, allocator, .limited(1024 * 1024));
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

    try cwd.writeFile(io, .{ .sub_path = output_file, .data = readme });
}
