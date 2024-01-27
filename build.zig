const std = @import("std");
const ZlvglBuild = @import("zlvgl/build.zig");

pub fn build(b: *std.Build) !void {

    // 默认构建目标
    const target = b.standardTargetOptions(.{});
    // 默认优化模式
    const optimize = b.standardOptimizeOption(.{});

    // ...

    // 获取包
    // const package = b.dependency("package_name", .{});
    const package_zlvgl = b.anonymousDependency("zlvgl", ZlvglBuild, .{
        .target = target,
        .optimize = optimize,
    });

    // 获取包构建的library，例如链接库
    const liblvgl = package_zlvgl.artifact("lvgl");

    // 获取包提供的模块
    const zlvgl = package_zlvgl.module("zlvgl");

    // zdec模块
    const zdec = b.addModule("zdec", .{
        .source_file = .{ .path = "src/zdec.zig" },
        .dependencies = &.{std.Build.ModuleDependency{ .name = "zlvgl", .module = zlvgl }},
    });

    const exe = b.addExecutable(.{
        .name = "exmaple",
        .root_source_file = .{ .path = "examples/example.zig" },
        .target = target,
        .optimize = optimize,
    });

    // for (liblvgl.include_dirs.items) |include_dir| {
    //     switch (include_dir) {
    //         .path => |path| {
    //             const path_str = path.getDisplayName();
    //             if (std.fs.path.isAbsolute(path_str)) {
    //                 std.debug.print("addIncludePath '{s}' from lib\n", .{path_str});
    //                 exe.addIncludePath(path);
    //             }
    //         },
    //         else => {},
    //     }
    // }
    exe.addIncludePath(.{ .path = "zlvgl/lvgl" });
    exe.addIncludePath(.{ .path = "zlvgl/lv_drivers" });

    // 引入模块
    exe.addModule("zlvgl", zlvgl);
    exe.addModule("zdec", zdec);

    // 链接依赖提供的库
    exe.linkLibC();
    exe.linkLibrary(liblvgl);

    b.installArtifact(liblvgl);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
