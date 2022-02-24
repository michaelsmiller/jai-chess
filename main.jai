#import "Basic";
Input :: #import "Input";
Window :: #import "Window_Creation"; // @note: maybe rename to avoid confusion
#import "GL";   // OpenGL
File :: #import "File"; // for reading files

#load "math.jai"; // my simple math library
#load "util.jai"; // timer code so far

// constants
vertex_shader_path   :: "board.vert";
fragment_shader_path :: "board.frag";

error :: (message : string, print_args : ..Any) {
  print(message, ..print_args);
  exit(1);
}

set_uniform :: (program : GLuint, cname : *u8, value : $T) {
  using gl;
  loc := glGetUniformLocation(program, cname);
  if loc < 0 {
    name := to_string(cname);
    error("location of uniform '%' not found. Might not be active.\n", name);
  }

  #if T == [2] s32 {
    glUniform2i(loc, value[0], value[1]);
  }
  else #if T == Vector2(s32) {
    glUniform2i(loc, value.x, value.y);
  }
  else #if T == float {
    glUniform1f(loc, value);
  }
  else #if T == [2] float {
    glUniform2f(loc, value[0], value[1]);
  }
  else #if T == [3] float {
    glUniform3f(loc, value[0], value[1], value[2]);
  }
  else #if T == Vector3(float) {
    glUniform3f(loc, value.x, value.y, value.z);
  }
  else #if T == [4] float {
    glUniform4f(loc, value[0], value[1], value[2], value[3]);
  }
  else #if T == [4] float {
    glUniform4f(loc, value[0], value[1], value[2], value[3]);
  }
  else {
    error("set_uniform: type '%' not supported yet!\nShould probably add it\n", T);
  }
}

compile_shader :: (shader_type : GLenum, source_path : string) -> GLuint {
  using gl; // @todo: put this at the top of files that are graphics only
  shader := glCreateShader(shader_type);
  shader_text, file_success := File.read_entire_file(source_path, true);
  defer free(shader_text);
  if !file_success error("There was an error reading the shader: %\n", source_path);

  _glShaderSource(shader, shader_text);
  glCompileShader(shader);
  compile_success : GLint;
  glGetShaderiv(shader, GL_COMPILE_STATUS, *compile_success);
  if !compile_success {
    DumpShaderInfoLog(shader, source_path);
    error("Shader compilation error. Exiting.\n");
  }
  return shader;
};

main :: () {
  window_size :: Vector2(s32).{800, 800};
  window := Window.create_window(window_size.x, window_size.y, "Chess");
  if !window error("Couldn't open window!");
  print("Successfully created window of size % pixels\n", window_size);

  version_major, version_minor :: 3, 1; // @note: OpenGL version hardcoded
  gl_create_context(window, version_major, version_minor);
  gl_load(*gl); // Makes OpenGL available
  using gl;

  {
    major, minor := gl_get_version();
    assert(major == version_major && minor == version_minor);
  }
  print("Loaded OpenGL function pointers, using version: %.%\n", version_major, version_minor);

  Vertex :: struct {
    x, y : float;        // coords
    tx, ty : float;      // texture coordinates
    ix, iy : GLint;      // index of what square this is on
  }

  make_vertex :: inline (x : float, y : float, tx : float, ty : float, ix : GLint, iy : GLint) -> Vertex {
    v : Vertex;
    v.x = x;
    v.y = y;
    v.tx = tx;
    v.ty = ty;
    v.ix = ix;
    v.iy = iy;
    return v;
  }

  nsquares_width :: 8;
  nsquares_height :: 8;
  nsquares :: nsquares_width * nsquares_height;
  nvertices :: nsquares * 6; // two triangles per square

  vertices : [nvertices] Vertex;
  ivert := 0;
  for i : 0..nsquares_width-1 {
    for j : 0..nsquares_height-1 {
      defer ivert += 1;
      xfrac := cast(float) i / cast(float)(nsquares_width);
      yfrac := cast(float) j / cast(float)(nsquares_height);
      // @note add in a range here when more stuff goes on the screen than board
      x  := lerp(-1., 1., xfrac);
      y  := lerp(-1., 1., yfrac);
      w  := 2 / cast(float) nsquares_width;
      h  := 2 / cast(float) nsquares_height;

      ix := cast(GLint) i;
      iy := cast(GLint) (nsquares_height - j - 1); // flip y axis back for square indices
      // print("ix = %, iy = %\n", ix, iy);
      itri1 := ivert * 6;
      itri2 := ivert * 6 + 3;
      vertices[itri1+0] = make_vertex(x  , y  , 0, 0, ix, iy); // first triangle
      vertices[itri1+1] = make_vertex(x  , y+h, 0, 1, ix, iy);
      vertices[itri1+2] = make_vertex(x+w, y+h, 1, 1, ix, iy);
      vertices[itri2+0] = make_vertex(x+w, y+h, 1, 1, ix, iy); // second triangle
      vertices[itri2+1] = make_vertex(x  , y  , 0, 0, ix, iy);
      vertices[itri2+2] = make_vertex(x+w, y  , 1, 0, ix, iy);
    }
  }

  vertex_buffer : GLuint;
  vao           : GLuint; // vertex array object
  glGenBuffers(1, *vertex_buffer);
  glGenVertexArrays(1, *vao);
  glBindVertexArray(vao);
  glBindBuffer(GL_ARRAY_BUFFER, vertex_buffer);
  // @note: if things aren't changing, maybe switch to DYNAMIC_DRAW
  glBufferData(GL_ARRAY_BUFFER, vertices.count * size_of(Vertex), vertices.data, GL_STATIC_DRAW);

  print("Compiling and linking shaders ...");
  program := glCreateProgram();
  vertex_shader := compile_shader(GL_VERTEX_SHADER, vertex_shader_path);
  fragment_shader := compile_shader(GL_FRAGMENT_SHADER, fragment_shader_path);
  glAttachShader(program, vertex_shader);
  glAttachShader(program, fragment_shader);
  glLinkProgram(program);
  print(" success!\n");
  glDeleteShader(vertex_shader); // only flags for deletion, doesn't take up time
  glDeleteShader(fragment_shader);
  glUseProgram(program); // need to use program to set uniforms in the shaders

  BoardShaderUniforms :: struct {
      white_color  := Color.{0.8, 0.8, 0.8};
      black_color  := Color.{0.4, 0.4, 0.4};
      // Uncomment these for a fun time (;
      // white_color  := Color.{0.7, 0.5, 0.2};
      // black_color  := Color.{0.3, 0.8, 0.1};

      border_color := Color.{0.0, 0.0, 0.0}; // black
      border_width :  float = 0.01; // units of square width
  }
  board_look : BoardShaderUniforms;

  // UNIFORMS
  {
    set_uniform(program, "blackColor",  board_look.black_color);
    set_uniform(program, "whiteColor",  board_look.white_color);
    set_uniform(program, "borderColor", board_look.border_color);
    set_uniform(program, "borderWidth", board_look.border_width);
    set_uniform(program, "squareDim",   Vector2(s32).{nsquares_width, nsquares_height});
    set_uniform(program, "t",  cast(float) 0.);
  }

  // ATTRIBUTES
  {
    // @note: need glVertexAttribIPointer when working with integer types, otherwise
    //        everything gets implicitly casted to float for some reason...
    offset : *Vertex : null; // giving OpenGL the right offsets (basically relative pointers)
    vsize : GLuint = size_of(Vertex);
    // The vertices and their data
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, xx false, vsize, cast(*void) *offset.x);
    // The texture coordinates
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, xx false, vsize, cast(*void) *offset.tx);
    // The indices of the square
    glEnableVertexAttribArray(2);
    glVertexAttribIPointer(2, 2, GL_INT, vsize, cast(*void) *offset.ix);
  }
  

  // game loop
  timer, total_timer : Timer;
  start_timer(*timer);
  start_timer(*total_timer);

  nframes : s64 = 0;
  toggle := false; // for debugging
  quit := false;
  framerate : float = 0.;
  sleep_milliseconds(10); // necessary for timer not to be set off
  while !quit { // game loop
    defer nframes += 1;
    
    // Framerate calculation, done every few frames for a good average
    time_sample_rate : s64 : 100;
    if nframes % time_sample_rate == 0 {
      stop_timer(*timer);
      defer start_timer(*timer);

      dt : float = get_seconds(*timer);
      framerate = cast(float) time_sample_rate / dt; // fps
      if nframes % (time_sample_rate) == 0 {
        // print("% fps\n", cast(u32)framerate);
      }

    }
    // absolute time calculation should be done once per frame
    {
      stop_timer(*total_timer); // don't start total_timer again
      ftime : float = get_seconds(*total_timer); // in seconds;
      set_uniform(program, "t",  ftime);
    }

    // HANDLE INPUT
    // Input.input_per_frame_event_and_flag_update();
    Input.update_window_events();
    event_count := Input.events_this_frame.count;
    for event: Input.events_this_frame {
      if event.type == .QUIT || (event.type == .KEYBOARD && event.key_code == .ESCAPE) {
        quit = true;
      }
      else if event.type == .KEYBOARD && event.key_pressed {
        if event.key_code == .ENTER {
          toggle = !toggle;
          print("Toggle is now %\n", toggle);
        }
        else if event.key_code == xx (#char "f" - 32) {
          print("% fps\n", cast(int)framerate);
        }
        else {
          print("Key % is pressed!\n", cast(u64)event.key_code);
        }
      }
    }

    // SIMULATE
    // @todo: make a board state and shit

    
    // GRAPHICS
    width, height : s32;
    {
      x, y : s32;
      success : bool;
      x, y, width, height, success = Window.get_dimensions(window, true);;
      if !success error("Did not get window dimensions correctly...\n");
    }
    glViewport(0, 0, xx width, xx height);

    // draw to backbuffer
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(program); // program is a shading program, specifically
    glBindVertexArray(vao); // have to bind every frame before drawing
    glDrawArrays(GL_TRIANGLES, 0, vertices.count);

    Window.swap_buffers(window); // @note soon will be deprecated because depends on GL

    reset_temporary_storage(); // allows us to allocate temporary stuff without fear every frame
  }

  print("Program exited and shut down correctly\n");
}
