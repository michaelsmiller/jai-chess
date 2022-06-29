#import "Basic";
#import "Compiler";

#run build();

build :: () {
  w := compiler_create_workspace();
  options := get_build_options(); // starting point is current options so args can propagate
  options.output_executable_name = "main";
  options.optimization_level = .DEBUG;

  // Add local modules/ path to import_paths
  import_path : [..] string;
  defer array_free(import_path);
  array_add(*import_path, ..options.import_path);
  array_add(*import_path, "modules");
  options.import_path = import_path;

  set_build_options(options, w); // must happen before we start compiling

  add_build_file("main.jai", w); // starts compiling asynchronously
  set_build_options_dc(.{do_output=false}); // don't generate an executable
}
