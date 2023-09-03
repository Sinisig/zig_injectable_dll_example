const std = @import("std");

pub fn build(b : * std.Build) void {
   const opt_target_platform  = b.standardTargetOptions(.{.default_target = .{
      .os_tag     = .windows,
      .cpu_model  = .baseline,
   }});
   const opt_optimize_mode    = b.standardOptimizeOption(.{});

   const dylib = b.addSharedLibrary(.{
      .name             = "zig-injectable-dll",
      .root_source_file = .{.path = "src/main.zig"},
      .target           = opt_target_platform,
      .optimize         = opt_optimize_mode,
   });

   b.installArtifact(dylib);
   dylib.linkLibC();

   return;
}

