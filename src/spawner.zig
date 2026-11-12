const std = @import("std");

const log = std.log.scoped(.spawner);

pub fn spawnFileManager(io: std.Io, allocator: std.mem.Allocator, args: []const []const u8) !void {
    const argv = try std.mem.concat(
        allocator,
        []const u8,
        &.{ &.{ "xdg-terminal-exec", "yazi" }, args },
    );
    defer allocator.free(argv);

    // Heap-allocate the Child so the detached waiter thread has a stable pointer
    const child = try allocator.create(std.process.Child);
    errdefer allocator.destroy(child);

    child.* = try std.process.spawn(io, .{
        .argv = argv,
        .stdout = .ignore,
        // Some terminals (like Ghostty) use stderr for their logging, and can get quite noisy
        .stderr = .ignore,
    });

    if (std.mem.join(allocator, " ", argv)) |argv_str| {
        defer allocator.free(argv_str);
        log.debug("spawning process: {s}", .{argv_str});
    } else |_| {}

    log.debug("process spawned (pid={})", .{child.id.?});

    // wait() needs to be called on a child after spawn() to clean up its resources on termination.
    // It shouldn't block the main program, so the waiting is done in a separate thread.
    const thread = try std.Thread.spawn(.{}, waitForChild, .{ io, allocator, child });
    thread.detach();
}

fn waitForChild(io: std.Io, allocator: std.mem.Allocator, child: *std.process.Child) void {
    defer allocator.destroy(child);

    const id = child.id.?;
    const term = child.wait(io) catch |err| {
        log.err("error waiting for process: {}", .{err});
        return;
    };
    log.debug("process terminated (pid={}): {}", .{ id, term });
}
