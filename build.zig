const std = @import("std");
const ZlvglBuild = @import("zlvgl/build.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 获取包
    // const package = b.dependency("package_name", .{});
    const dep_zlvgl = b.anonymousDependency("zlvgl", ZlvglBuild, .{
        .target = target,
        .optimize = optimize,
    });

    // 获取包构建的library
    const liblvgl = dep_zlvgl.artifact("lvgl");

    // 获取包提供的模块
    const zlvgl = dep_zlvgl.module("zlvgl");

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

    // add C include paths
    ZlvglBuild.addIncludePathsFromDependency(exe, dep_zlvgl);

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
