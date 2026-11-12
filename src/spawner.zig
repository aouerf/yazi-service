const std = @import("std");
const Context = @import("Context.zig");

const log = std.log.scoped(.spawner);

pub fn spawnFileManager(context: *const Context, args: []const []const u8) !void {
    const allocator = context.allocator;
    const io = context.io;

    const argv = try std.mem.concat(
        allocator,
        []const u8,
        &.{ &.{ "xdg-terminal-exec", "yazi" }, args },
    );
    defer allocator.free(argv);

    var child = try std.process.spawn(io, .{
        .argv = argv,
        .stdout = .ignore,
        // Some terminals (like Ghostty) use stderr for their logging, and can get quite noisy
        .stderr = .ignore,
    });
    errdefer child.kill(io);

    if (std.mem.join(allocator, " ", argv)) |argv_str| {
        defer allocator.free(argv_str);
        log.debug("spawning process: {s}", .{argv_str});
    } else |_| {}

    log.debug("process spawned (pid={})", .{child.id.?});

    // wait() needs to be called on a child after spawn() to clean up its resources on termination.
    // It shouldn't block the main program, so the waiting is done in a separate thread.
    const thread = try std.Thread.spawn(.{}, waitForChild, .{child});
    thread.detach();
}

fn waitForChild(spawned_child: std.process.Child) void {
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    const io = threaded.io();
    var child = spawned_child;

    const id = child.id.?;
    const term = child.wait(io) catch |err| {
        log.err("error waiting for process: {}", .{err});
        return;
    };
    log.debug("process terminated (pid={}): {}", .{ id, term });
}
