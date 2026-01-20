const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    main_mod.addCSourceFile(.{ .file = b.path("src/vtable.c") });
    main_mod.linkSystemLibrary("libsystemd", .{});

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
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}

fn installServiceFiles(b: *std.Build, filename: []const u8) void {
    const wf = b.addWriteFiles();
    const exec_path = b.pathJoin(&.{ b.install_prefix, "bin", filename });

    installFile(
        b,
        wf,
        b.pathJoin(&.{ "share", "systemd", "user", "yazi-service.service" }),
        b.fmt(
            \\[Unit]
            \\Description=File Manager service (Yazi implementation)
            \\
            \\[Service]
            \\Type=dbus
            \\BusName=org.freedesktop.FileManager1
            \\ExecStart={s}
        , .{exec_path}),
    );
    installFile(
        b,
        wf,
        b.pathJoin(&.{ "share", "dbus-1", "services", "yazi-service.service" }),
        b.fmt(
            \\[D-BUS Service]
            \\Name=org.freedesktop.FileManager1
            \\Exec={s}
            \\SystemdService={s}.service
        , .{ exec_path, filename }),
    );
}

fn installFile(
    b: *std.Build,
    wf: *std.Build.Step.WriteFile,
    path: []const u8,
    data: []const u8,
) void {
    const file = wf.add(path, data);
    const install = b.addInstallFile(file, path);
    b.getInstallStep().dependOn(&install.step);
}
