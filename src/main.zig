const std = @import("std");
const c = @import("c.zig").c;
const InterfaceHandler = @import("InterfaceHandler.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var r: c_int = undefined;

    var bus: ?*c.sd_bus = undefined;
    r = c.sd_bus_default_user(&bus);
    if (r < 0) {
        std.log.err("sd_bus_default_user failed: {s}", .{c.strerror(-r)});
        return error.Dbus;
    }
    defer _ = c.sd_bus_unref(bus);

    const allocator = arena.allocator();
    try InterfaceHandler.init(&allocator, bus);
    defer InterfaceHandler.deinit(bus);

    while (true) {
        r = c.sd_bus_process(bus, null);
        if (r < 0) {
            std.log.err("sd_bus_process failed: {s}", .{c.strerror(-r)});
            return error.Dbus;
        }
        if (r > 0) {
            continue;
        }

        r = c.sd_bus_wait(bus, std.math.maxInt(u64));
        if (r < 0) {
            std.log.err("sd_bus_wait failed: {s}", .{c.strerror(-r)});
            return error.Dbus;
        }
    }
}

export fn handle_bus_message(
    m: *c.sd_bus_message,
    userdata: ?*anyopaque,
    ret_error: ?*c.sd_bus_error,
) callconv(.c) c_int {
    _ = ret_error;

    const interface = std.mem.span(c.sd_bus_message_get_interface(m));
    if (!std.mem.eql(u8, interface, InterfaceHandler.NAME)) {
        std.log.warn("unsupported interface: {s}", .{interface});
        return c.sd_bus_reply_method_return(m, null);
    }

    const allocator = @as(*std.mem.Allocator, @ptrCast(@alignCast(userdata))).*;
    return InterfaceHandler.handleMessage(allocator, m);
}
