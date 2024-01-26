const std = @import("std");

var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = general_purpose_allocator.allocator();

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    ret: {
        const msg = std.fmt.allocPrint(gpa, format ++ "\n", args) catch break :ret;
        std.io.getStdErr().writeAll(msg) catch {};
    }
    std.process.exit(1);
}

pub fn main() anyerror!void {
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const all_args = try std.process.argsAlloc(arena);
    const args = all_args[1..];

    if (args.len == 0) fatal("No args specified", .{});

    var child = std.ChildProcess.init(args, arena);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.request_resource_usage_statistics = true;

    var stdout = std.ArrayList(u8).init(arena);
    var stderr = std.ArrayList(u8).init(arena);

    try child.spawn();
    try child.collectOutput(&stdout, &stderr, 50 * 1024);
    const term = try child.wait();

    const stdout_h = std.io.getStdOut().writer();
    const stderr_h = std.io.getStdErr().writer();
    try stdout_h.print("STDOUT:\n{s}\n", .{stdout.items});
    try stderr_h.print("STDERR:\n{s}\n", .{stderr.items});
    try stdout_h.print("MAX RSS: {?d}\n", .{child.resource_usage_statistics.getMaxRss()});

    switch (term) {
        .Exited => |code| if (code != 0) {
            return error.ChildError;
        },
        else => return error.ChildError,
    }
}
