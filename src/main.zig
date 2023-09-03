const std      = @import("std");
const builtin  = @import("builtin");
const c        = @cImport({
   @cInclude("windows.h");
});

// These checks aren't ~technically~ required, but they can help a lot to prevent
// weird build configurations from generating invalid executables and prevent
// headaches and wasted debugging.
comptime {
   if (builtin.os.tag != .windows) {
      @compileError("target operating system must be windows");
   }
   if (builtin.output_mode != .Lib or builtin.link_mode != .Dynamic) {
      @compileError("output executable format must be a shared/dynamic library");
   }
}

// Defines the DLL initialization entrypoint.  Note that it is a normal, non-exported
// public function.  The zig compiler will generate the startup code for us, but this
// is contingent on a public function named "DllMain" being present at our library root.
// For more information, reference "start.zig" contained in Zig's source tree.
pub fn DllMain(
   hinstDLL    : std.os.windows.HINSTANCE,
   fdwReason   : std.os.windows.DWORD,
   lpvReserved : std.os.windows.LPVOID,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL {
   _ = lpvReserved;

   // Check to make sure we only start when loading the DLL.
   if (fdwReason != c.DLL_PROCESS_ATTACH) {
      return c.TRUE;
   }

   // Attempt to create the main thread.  We create a separate thread for execution
   // because we are limited to a small number of functions within DllMain because
   // the dynamic linker is being held up executing DllMain.  DllMain should be as
   // simple as possible, otherwise the dynamic linker will be held up and never
   // "finish" "loading" the library.  By creating a new thread, we can return control
   // back to the dynamic linker and get a fully functional environment.
   const handle_main_thread = c.CreateThread(
      null,
      0,
      win32MainThreadEntrypoint,
      hinstDLL,
      0,
      null,
   ) orelse {
      // If we fail to create the main thread, we want to unload it so we can
      // try again.  There's not much we can do if FreeLibrary() fails, so we
      // ignore its return code.
      _ = std.os.windows.FreeLibrary(@ptrCast(hinstDLL));
      return c.FALSE;
   };

   // Attempt to close the open thread handle.  The main thread will continue
   // to execute in the background.
   if (c.CloseHandle(handle_main_thread) == c.FALSE) {
      return c.FALSE;
   }

   // Return success to the dynamic linker
   return c.TRUE;
}

fn win32MainThreadEntrypoint(param : c.LPVOID) callconv(std.os.windows.WINAPI) c.DWORD {
   // We defer the actual main to another function so that the defer and errdefer
   // keywords function as expected.  Since we call FreeLibraryAndExitThread() to
   // unload our library and end the thread at the end of the main thread function,
   // no code will be executed after FreeLibraryAndExitThread() is called.  This is
   // why we use "unreachable" instead of actually returning.  By moving our actual
   // main to another function, we can return from it like normal without worrying
   // about this small detail.  If you are worried about performance, the compiler
   // will usually inline the function call.  If you don't trust the compiler to do
   // this, you can use "@call(.always_inline, win32MainThread, .{})" to force the
   // compiler to be guarunteed to always inline the function call.
   c.FreeLibraryAndExitThread(@ptrCast(@alignCast(param)), win32MainThread());
   unreachable;
}

fn win32MainThread() c.DWORD {
   // You can do whatever you want at this point.  What would be ideal is
   // creating a wrapper interface sort of thing to abstract all this dirty
   // low-level stuff as well has provide an interface for specifying features
   // such as a process whitelist, console, etc.

   if (c.AllocConsole() == c.FALSE) {
      return 1;
   }
   defer _ = c.FreeConsole();

   std.debug.print("Hello from the other side~\n", .{});
   std.time.sleep(1000000000 * 5);

   return 0;
}
