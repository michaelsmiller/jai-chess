#import "Basic";
#import "Compiler";

EXECUTABLE_NAME :: "main";

build :: () {
  w := compiler_create_workspace(); // isolated environment
  if !w {
    print("Workspace creation failed!\n");
    return;
  }

  options := get_build_options(); // defaults + current command line options
  options.output_executable_name = EXECUTABLE_NAME;
  options.backend = .X64; // Compile directly to x64 instead of with LLVM
  options.optimization_level = .DEBUG; // debug build, array bounds checking, no optimizations
  // options.optimization_level = .RELEASE;

  // Add local modules/ path to import_paths
  import_path : [..] string;
  defer array_free(import_path);
  array_add(*import_path, ..options.import_path);
  array_add(*import_path, "modules");
  options.import_path = import_path;

  set_build_options(options, w); // must happen before we start compiling

  compiler_begin_intercept(w);
  add_build_file("main.jai", w); // this is asynchronous
  message_loop();
  compiler_end_intercept(w);

  set_build_options_dc(.{do_output=false}); // don't generate an executable for build.jai
}

// @note: this is where we put any intercepts necessary
message_loop :: () {
  while true {
    message := compiler_wait_for_message();
    if message.kind == .COMPLETE {
      print("\n------------\nBuilt '%'\n------------\n\n", EXECUTABLE_NAME);
      break;
    }
  }
}

#run build();
