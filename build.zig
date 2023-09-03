const std = @import("std");

pub fn build(b : * std.Build) void {
   // Determines the platform to build for.  We manually set the default target to Windows
   // and set the CPU model to baseline.  This makes sure we default to only target Windows
   // (since we only support Windows) and not make use of CPU extensions, such as x86's AVX
   // instruction set.  This improves binary compatibility, but at the cost of a little performance.
   // If you try to build on a CPU with extensions unavailable to another CPU, by default the
   // Zig compiler will make full use of the host's extensions.  Running this binary on the
   // unsupported CPU will crash the program with an illegal instruction exception.  If you
   // don't plan on distributing your binary or will distribute different versions compiled
   // with different CPU features, you can remove ".cpu_mode = .baseline".
   const opt_target_platform  = b.standardTargetOptions(.{.default_target = .{
      .os_tag     = .windows,
      .cpu_model  = .baseline,
   }});

   // Determine the optimization mode to use as specified by the build command
   // (zig build -Doptimize=Debug/ReleaseSafe/ReleaseSmall/ReleaseFast).
   const opt_optimize_mode    = b.standardOptimizeOption(.{});

   // Creates a new dynamic library which uses our target platform specified above,
   // optimization profile specified above, and our entrypoint in "src/main.zig".
   // The output binary will be at "zig-out/lib/(name).dll".
   const dylib = b.addSharedLibrary(.{
      .name             = "zig-injectable-dll",
      .root_source_file = .{.path = "src/main.zig"},
      .target           = opt_target_platform,
      .optimize         = opt_optimize_mode,
   });

   // Tells the builder to add the dynamic library we created as a build artifact
   // and will add it to the build step.
   b.installArtifact(dylib);

   // Since we are making use of the Win32 API, we unfortunately need to link against
   // it.  This can easily be achieved by linking libc to our library.
   dylib.linkLibC();

   return;
}
