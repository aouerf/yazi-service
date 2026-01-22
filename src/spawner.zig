const std = @import("std");

const log = std.log.scoped(.spawner);

pub fn spawnFileManager(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const argv = try std.mem.concat(
        allocator,
        []const u8,
        &.{ &.{ "xdg-terminal-exec", "yazi" }, args },
    );
    defer allocator.free(argv);

    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Ignore;
    // Some terminals (like Ghostty) use stderr for their logging, and can get quite noisy
    child.stderr_behavior = .Ignore;

    if (std.mem.join(allocator, " ", argv)) |argv_str| {
        defer allocator.free(argv_str);
        log.debug("spawning process: {s}", .{argv_str});
    } else |_| {}

    try child.spawn();
    log.debug("process spawned (pid={})", .{child.id});

    // wait() needs to be called on a child after spawn() to clean up its resources on termination.
    // It shouldn't block the main program, so the waiting is done in a separate thread.
    const thread = try std.Thread.spawn(.{}, waitForChild, .{&child});
    thread.detach();
}

fn waitForChild(child: *std.process.Child) void {
    const id = child.id;
    const term = child.wait() catch |err| {
        log.err("error waiting for process: {}", .{err});
        return;
    };
    log.debug("process terminated (pid={}): {}", .{ id, term });
}
