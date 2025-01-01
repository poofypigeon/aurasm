const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "aurasm",
        .root_source_file = b.path("src/aurasm.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath(b.path("gperf"));

    b.installArtifact(exe);

    exe.addIncludePath(.{
        .path = "src/",
    });

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addExecutable(.{
        .name = "aurasm",
        .root_source_file = b.path("src/aurasm.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_tests.addIncludePath(b.path("gperf"));

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
