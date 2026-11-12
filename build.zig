const std = @import("std");
const Translator = @import("translate_c").Translator;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const translate_c = b.dependency("translate_c", .{});
    const translator: Translator = .init(translate_c, .{
        .c_source_file = b.path("src/c.h"),
        .target = target,
        .optimize = optimize,
        .link_system_libs = &.{
            .{ .name = "libsystemd" },
        },
    });
    translator.mod.addCSourceFile(.{ .file = b.path("src/vtable.c") });

    const main_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = translator.mod,
            },
        },
    });

    const exe = b.addExecutable(.{
        .name = "yazi-service",
        .root_module = main_mod,
    });
    b.installArtifact(exe);

    installServiceFiles(b, exe.out_filename);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
}

fn installServiceFiles(b: *std.Build, filename: []const u8) void {
    const bin_path = b.graph.path(.deployed_bin, filename);

    installServiceFile(
        b,
        bin_path,
        b.pathJoin(&.{ "share", "systemd", "user", "yazi-service.service" }),
        b.fmt(
            \\[Unit]
            \\Description=File Manager service (Yazi implementation)
            \\
            \\[Service]
            \\Type=dbus
            \\BusName=org.freedesktop.FileManager1
            \\KillMode=process
            \\ExecStart=%s
        , .{}),
    );

    installServiceFile(
        b,
        bin_path,
        b.pathJoin(&.{ "share", "dbus-1", "services", "yazi-service.service" }),
        b.fmt(
            \\[D-BUS Service]
            \\Name=org.freedesktop.FileManager1
            \\Exec=%s
            \\SystemdService=yazi-service.service
        , .{}),
    );
}

fn installServiceFile(
    b: *std.Build,
    bin_path: std.Build.LazyPath,
    path: []const u8,
    contents: []const u8,
) void {
    // The install prefix isn't known in the configure phase, so embed it in the make phase
    const cmd = b.addSystemCommand(&.{ "printf", b.fmt("{s}\n", .{contents}) });
    cmd.addDirectoryArg2(bin_path, .{ .make_absolute = true });

    const file = cmd.captureStdOut(.{ .basename = std.fs.path.basename(path) });
    const install = b.addInstallFile(file, path);
    b.getInstallStep().dependOn(&install.step);
}
