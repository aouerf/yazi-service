const std = @import("std");
const c = @import("c.zig").c;

const log = std.log.scoped(.handler);

pub const NAME = "org.freedesktop.FileManager1";
const OBJECT_PATH = "/org/freedesktop/FileManager1";

// Zig sees sd_bus_vtable as an opaque type, and arrays of opaque types aren't allowed.
// The SD_BUS_* macros also don't work well in Zig.
// So instead, the vtable is defined in C and exposed as a pointer.
extern fn get_vtable() *c.sd_bus_vtable;

pub fn init(allocator: *const std.mem.Allocator, bus: ?*c.sd_bus) !void {
    var r = c.sd_bus_add_object_vtable(
        bus,
        null,
        OBJECT_PATH,
        NAME,
        get_vtable(),
        @constCast(allocator),
    );
    if (r < 0) {
        log.err("sd_bus_add_object_vtable failed: {s}", .{c.strerror(-r)});
        return error.Dbus;
    }

    r = c.sd_bus_request_name(bus, NAME, 0);
    if (r < 0) {
        log.err("sd_bus_request_name failed: {s}", .{c.strerror(-r)});
        return error.Dbus;
    }
}

pub fn deinit(bus: ?*c.sd_bus) void {
    _ = c.sd_bus_release_name(bus, NAME);
}

pub fn handleMessage(allocator: std.mem.Allocator, message: *c.sd_bus_message) c_int {
    const method = blk: {
        const method = std.mem.span(c.sd_bus_message_get_member(message));
        break :blk std.meta.stringToEnum(enum {
            ShowFolders,
            ShowItems,
            ShowItemProperties,
        }, method) orelse {
            log.warn("unsupported method: {s}", .{method});
            return c.sd_bus_reply_method_return(message, null);
        };
    };

    log.info("handling message: {s}{}", .{ NAME, method });
    if (method == .ShowItemProperties) {
        log.warn("unimplemented method: {s}", .{@tagName(method)});
    }

    var r: c_int = undefined;

    r = c.sd_bus_message_enter_container(message, 'a', "s");
    if (r < 0) {
        log.err("sd_bus_message_enter_container failed: {s}", .{c.strerror(-r)});
        return r;
    }

    var uris: std.ArrayList([]const u8) = .empty;
    defer uris.deinit(allocator);
    while (true) {
        var uri_str: [*c]const u8 = undefined;
        r = c.sd_bus_message_read(message, "s", &uri_str);
        if (r < 0) {
            log.err("sd_bus_message_read failed: {s}", .{c.strerror(-r)});
            return r;
        }
        if (r == 0) {
            break;
        }

        const uri = std.Uri.parse(std.mem.span(uri_str)) catch |err| {
            log.warn("failed to parse uri {s}: {}", .{ uri_str, err });
            continue;
        };
        if (!std.mem.eql(u8, "file", uri.scheme)) {
            log.warn("uri scheme {s} in {s} is not of type file", .{ uri.scheme, uri_str });
            continue;
        }
        uris.append(allocator, uri.path.percent_encoded) catch |err| {
            log.warn("failed to enqueue uri {s}: {}", .{ uri.path.percent_encoded, err });
            continue;
        };
    }

    r = c.sd_bus_message_exit_container(message);
    if (r < 0) {
        log.err("sd_bus_message_exit_container failed: {s}", .{c.strerror(-r)});
        return r;
    }

    spawnFileManager(allocator, uris.items) catch |err| {
        log.warn("failed to spawn process: {}", .{err});
    };

    return c.sd_bus_reply_method_return(message, null);
}

fn spawnFileManager(allocator: std.mem.Allocator, args: []const []const u8) !void {
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
        log.info("spawning process: {s}", .{argv_str});
    } else |_| {}

    try child.spawn();
}
