#import "Basic";
// Window :: #import "Window_Creation"; // @todo: move back to GLFW for control over # samples/pixel
#import "glfw";
#import "GL";   // OpenGL, doesn't need a namespace because most functions are in a global struct anyway
File :: #import "File"; // for reading files

STB :: #import "stb_image"; // for reading pngs into memory

#load "math.jai"; // my simple math library
#load "util.jai"; // just timer code so far
#load "chess.jai"; // board/piece state and game logic

MSAA :: false;

// Global state
//
toggle           := false;    // for debugging
to_redraw_pieces := false;    // Whether we need to recreate piece vertices and redraw this frame.
nframes : s64 = 0;            // number of frames that have passed up to this point
time_sample_rate : s64 : 100; // for framerate sampling
framerate : float = 0.;       // Written to and displayed on command

board : Board;                // The internal game state
NUM_SQUARES :: board.W * board.H; // should be 64

InputState :: enum {
  DEFAULT;
  PLACE;
};
input_state : InputState = .DEFAULT; // The mode of inputting character by character
algebra_buffer_loc : s32;            // The current position in a piece location buffer being written to
algebra_buffer : [3] u8;             // Piece location buffer, algebraic notation (e.g. pe4)
// @todo: add global for registering current move and move history

// End global state


error :: (message : string, print_args : ..Any) {
  print(message, ..print_args);
  glfwTerminate();
  exit(1);
}

check_framebuffer_status :: (err_on_failure := true) -> (bool, GLenum) {
  e := glCheckFramebufferStatus(GL_FRAMEBUFFER);
  if e == GL_FRAMEBUFFER_COMPLETE return false, e;

  if e == {
    case GL_FRAMEBUFFER_UNDEFINED;               print("ERROR: GL_FRAMEBUFFER_UNDEFINED\n");
    case GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT;   print("ERROR: GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT\n");
    case GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT;   print("ERROR: GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT\n");
    case GL_FRAMEBUFFER_UNSUPPORTED;             print("ERROR: GL_FRAMEBUFFER_UNSUPPORTED\n");
    case GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE;  print("ERROR: GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE\n");

    case; print("FRAMEBUFFER STATUS: % (add to check_framebuffer_status())\n", to_hex(e));
  }
  if err_on_failure exit(1);
  return true, e;
}

check_gl_error :: (err_on_failure := true) -> (bool, GLenum) {
  e := glGetError();
  if e == GL_NO_ERROR return false, e;

  if e == {
    case GL_INVALID_ENUM;                  print("ERROR: GL_INVALID_ENUM\n");
    case GL_INVALID_VALUE;                 print("ERROR: GL_INVALID_VALUE\n");
    case GL_INVALID_OPERATION;             print("ERROR: GL_INVALID_OPERATION\n");
    case GL_INVALID_FRAMEBUFFER_OPERATION; print("ERROR: GL_INVALID_FRAMEBUFFER_OPERATION\n");
                                           check_framebuffer_status(err_on_failure);

    case; print("GL ERROR: % (add to check_gl_error())\n", to_hex(e));
  }
  if err_on_failure exit(1);
  return true, e;
}

// callbacks
framebuffer_size_callback :: (window : *GLFWwindow, width : s32, height : s32) #c_call {
  // new_context : Context;
  // push_context new_context {
    glViewport(0, 0, xx width, xx height);
  // }
}

char_callback :: (window : *GLFWwindow, char : u32) #c_call {
  new_context : Context;
  push_context new_context {
    char2 := cast(u8)char;

    if input_state == .PLACE {
      if algebra_buffer_loc == -1 {
        algebra_buffer_loc = 0;
        return;
      }

      algebra_buffer[algebra_buffer_loc] = char2;
      algebra_buffer_loc += 1;
      if algebra_buffer_loc == 3 {
        s : string;
        s.count = 3;
        s.data  = algebra_buffer.data;
        print("String entered: %\n", s);
        success, p, loc := algebra_to_piece_loc(s);

        print("Piece: %\n", p);
        success = place(*board, p, loc);
        if !success print("WARNING: Failed to place piece!\n");
        if success to_redraw_pieces = true;
        input_state = .DEFAULT;
        glfwSetCharCallback(window, null);
        glfwSetKeyCallback (window, key_callback);
      }
      return;
    }
    else error("How did we get here?\n");
  }
}

key_callback :: (window : *GLFWwindow, key : s32, scancode : s32, action : s32, mods : s32) #c_call {
  new_context : Context;
  push_context new_context {
    if action == GLFW_RELEASE return;

    if action == GLFW_PRESS && key == GLFW_KEY_ESCAPE {
      glfwSetWindowShouldClose(window, GLFW_TRUE);
      return;
    }

    if action == GLFW_PRESS && key == GLFW_KEY_ENTER {
        toggle = !toggle;
        print("Toggle is now %\n", toggle);
    }
    else if action == GLFW_PRESS && key == GLFW_KEY_F {
      if nframes > time_sample_rate print("Respects paid: % fps\n", cast(int)framerate);
    }
    else if action == GLFW_PRESS && key == GLFW_KEY_P {
      print("Entering P mode\n");
      input_state = .PLACE;
      glfwSetCharCallback(window, char_callback);
      glfwSetKeyCallback(window, null);
      algebra_buffer_loc = -1;
    }
    else { // print the key pressed
      builder : String_Builder;
      init_string_builder(*builder, 3);
      defer free_buffers(*builder);
      if mods & GLFW_MOD_CONTROL append(*builder, "Ctrl-");
      if mods & GLFW_MOD_ALT     append(*builder, "Alt-");
      if mods & GLFW_MOD_SHIFT   append(*builder, "Shift-");
      append(*builder, tprint("Pressed: %\n", to_string(glfwGetKeyName(key, scancode))));
      print(builder_to_string(*builder, __temporary_allocator));
    }
  }
}

get_vert_frag_paths :: (basename : string, folder : string = "shaders") -> (string, string) {
  vert :: ".vert";
  frag :: ".frag";

  allocator := context.allocator;
  context.allocator = __temporary_allocator; // shouldn't need to hold filenames for long
  defer context.allocator = allocator;

  builder : String_Builder;
  init_string_builder(*builder);
  // defer free_buffers(*builder);
  append(*builder, folder);
  if folder.count > 0 append(*builder, "/");
  append(*builder, basename);
  append(*builder, vert);
  vert_path := builder_to_string(*builder);
  reset(*builder); // maybe not necessary

  init_string_builder(*builder);
  append(*builder, folder);
  if folder.count > 0 append(*builder, "/");
  append(*builder, basename);
  append(*builder, frag);
  frag_path := builder_to_string(*builder);

  return vert_path, frag_path;
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
  else {
    error("set_uniform: type '%' not supported yet!\nShould probably add it\n", T);
  }
}

compile_shader :: (shader_type : GLenum, source_path : string) -> GLuint {
  using gl;
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
  version_major, version_minor :: 3, 1; // @note: OpenGL version hardcoded
  startup_timer : Timer;
  start_timer(*startup_timer);

  window_size :: Vector2(s32).{800, 800};
  if !glfwInit() error("glfwInit() failed");
  NSAMPLES : s32 : 4;
  glfwWindowHint(GLFW_SAMPLES, NSAMPLES); // for super-sampling!
  window := glfwCreateWindow(window_size.x, window_size.y, "Chess", null, null);
  if !window error("Couldn't open GLFW window.");
  glfwMakeContextCurrent(window);

  // callbacks
  glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
  glfwSetKeyCallback(window, key_callback);
  glfwSwapInterval(1);

  print("Successfully created window of size % pixels\n", window_size);
  {
    ns := glfwGetWindowAttrib(window, GLFW_SAMPLES);
    print("nsamples = %, wanted %\n", ns, NSAMPLES);
  }

  gl_load(*gl, glfwGetProcAddress); // Makes OpenGL functions available
  using gl;

  // OpenGL defaults here:
  {
    major, minor := gl_get_version();
    print("OpenGL version: %.%\n", major, minor);
    assert(major == version_major && minor == version_minor);
  }
  print("Loaded OpenGL instance\n");
  print(" Vendor:   %\n", to_string(glGetString(GL_VENDOR)));
  print(" Renderer: %\n", to_string(glGetString(GL_RENDERER)));
  glEnable(GL_MULTISAMPLE);
  glClearColor(0.2, 0.2, 0.2, 1.); // a pleasant gray

  // Should correspond exactly with what is fed to vertex buffer
  // @todo: make some functions to easily load into vertex buffer given fewer inputs
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

  // @todo: ask about this in the discord, because I'm not sure if it's a feature that
  //        components of a constant struct literal cannot be known at compile time...
  nsquare_width  :: 8;
  nsquare_height :: 8;
  square_dim :: Vector2(s32).{nsquare_width, nsquare_height};
  nsquares :: nsquare_width*nsquare_height;

  vertices       : [4*nsquares] Vertex; // 4 vertices per square
  vertex_indices : [6*nsquares] GLuint; // 2 triangles per square, each has 3 vertices
  ivert := 0;
  for i : 0..square_dim.x-1 {
    for j : 0..square_dim.y-1 {
      defer ivert += 1;
      // @todo: this calculation is in screen space coordinates, but will need to be moved to
      //        board space coordinates when other widgets appear on the screen.
      xfrac := cast(float) i / cast(float)(square_dim.x);
      yfrac := cast(float) j / cast(float)(square_dim.y);
      x  := lerp(-1., 1., xfrac);
      y  := lerp(-1., 1., yfrac);
      w  := 2 / cast(float) square_dim.x;
      h  := 2 / cast(float) square_dim.y;

      ix := cast(GLint) i;
      iy := cast(GLint) (square_dim.y - j - 1); // flip y axis back for square indices
      itri1 := ivert * 4;
      // @note: OpenGL texture coordinates are NOT flipped on y for some reason
      //        so the top of an image has texture coordinate 1, not 0.
      vertices[4*ivert+0] = make_vertex(x  , y  , 0, 1, ix, iy); // counter-clockwise starting in UL
      vertices[4*ivert+1] = make_vertex(x  , y+h, 0, 0, ix, iy);
      vertices[4*ivert+2] = make_vertex(x+w, y+h, 1, 0, ix, iy);
      vertices[4*ivert+3] = make_vertex(x+w, y  , 1, 1, ix, iy);

      // Bottom left triangle
      vertex_indices[6*ivert+0] = cast(u32) (4*ivert+0);
      vertex_indices[6*ivert+1] = cast(u32) (4*ivert+1);
      vertex_indices[6*ivert+2] = cast(u32) (4*ivert+2);
      // Upper right triangle
      vertex_indices[6*ivert+3] = cast(u32) (4*ivert+2);
      vertex_indices[6*ivert+4] = cast(u32) (4*ivert+0);
      vertex_indices[6*ivert+5] = cast(u32) (4*ivert+3);
    }
  }

  PieceVertex :: struct {
    using piece : Piece;
    pos         : Vector2(float);
    tex         : Vector2(float);
  }

  make_piece_vertex :: (color : PieceColor, type : PieceType, px : float, py : float, tx : float, ty : float) -> PieceVertex {
    p : PieceVertex;
    p.color = color;
    p.type = type;
    p.pos.x = px;
    p.pos.y = py;
    p.tex.x = tx;
    p.tex.y = ty;
    return p;
  }

  // enums for color and type of chess pieces, pretty harmless
  using PieceColor;
  using PieceType;

  // set_position_from_file(*board, "positions/test.chess");
  set_position_from_file(*board, "positions/starting.chess");

  // Create PieceVertex array from the other array
  piece_vertices : [..] PieceVertex;
  piece_indices  : [..] u32;
  defer array_free(piece_vertices);
  defer array_free(piece_indices);
  // @note: important to reserve as many vertices as we need so that the arrays never
  //        get reallocated, and we can pass their pointers to OpenGL once and not think
  //        about that again.
  array_reserve(*piece_vertices, 4*(NUM_SQUARES+4)); // a piece for every square plus 4 should be enough
  array_reserve(*piece_indices , 6*(NUM_SQUARES+4));

  // actually updates piece_vertices and piece_indices, maybe name should change
  update_piece_vertices :: (piece_vertices : *[..] PieceVertex, piece_indices : *[..] u32 ) { // this will be a function for computing the vertex/index data for piece texture rectangles
    array_reset(piece_vertices);
    array_reset(piece_indices);
    n := 0;
    for *piece : board.squares {
      if empty(<<piece) continue;
      defer n += 1;
      // @todo: this calculation is in screen space coordinates, but will need to be moved to
      //        board space coordinates when other widgets appear on the screen.
      xfrac := cast(float) piece.loc.x / cast(float)(square_dim.x);
      yfrac := cast(float) piece.loc.y / cast(float)(square_dim.y);
      // @note add in a range here when more stuff goes on the screen than board
      x  := lerp(-1., 1., xfrac);
      y  := lerp(-1., 1., yfrac);
      w  := 2 / cast(float) square_dim.x;
      h  := 2 / cast(float) square_dim.y;

      using piece;
      // 4 corners of the square
      array_add(piece_vertices, make_piece_vertex(color, type, x  , y  , 0, 1)); // UL
      array_add(piece_vertices, make_piece_vertex(color, type, x  , y+h, 0, 0)); // LL
      array_add(piece_vertices, make_piece_vertex(color, type, x+w, y+h, 1, 0)); // LR
      array_add(piece_vertices, make_piece_vertex(color, type, x+w, y  , 1, 1)); // UR

      off := cast(u32) (n*4); // index offset in piece_vertices

      // LL triangle
      array_add(piece_indices, off+0);
      array_add(piece_indices, off+1);
      array_add(piece_indices, off+2);
      // UR triangle
      array_add(piece_indices, off+2);
      array_add(piece_indices, off+3);
      array_add(piece_indices, off+0);
    }
  }
  update_piece_vertices(*piece_vertices, *piece_indices);
  print("Created % pieces, % vertices, % indices.\n", num_pieces(*board), piece_vertices.count, piece_indices.count);
  assert(num_pieces(*board) == num_pieces(*board, .WHITE) + num_pieces(*board, .BLACK));

  VertexSet :: struct {
    vao : GLuint; // vertex array object
    ebo : GLuint; // element buffer object
    vbo : GLuint; // vertex buffer object
  }
  create_vertex_set :: inline (indices : [] u32, vertices : [] $T) -> VertexSet {
    using gl;
    vs : VertexSet;
    // vao            : GLuint; // output
    // element_buffer : GLuint; // storage for triangle vertex indices
    // vertex_buffer  : GLuint; // storage for square vertices
    glGenVertexArrays(1, *vs.vao);
    glBindVertexArray(vs.vao);

    glGenBuffers(1, *vs.ebo);
    glGenBuffers(1, *vs.vbo);

    // @todo: replace GL_STATIC_DRAW with a variable so that we can add and remove pieces at will
    update_vs(*vs, indices, vertices);
    return vs;
  }

  update_vs :: (vs : *VertexSet, indices : [] u32, vertices : [] $T) {
    using gl;
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vs.ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.count*size_of(u32), indices.data, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, vs.vbo);
    glBufferData(GL_ARRAY_BUFFER, vertices.count * size_of(T), vertices.data, GL_STATIC_DRAW);
  }

  compile_shader_program :: (basename : string) -> GLuint {
    using gl;
    program := glCreateProgram();
    print("Compiling and linking '%' shaders ...", basename);
    vert_path, frag_path := get_vert_frag_paths(basename);
    vertex_shader := compile_shader(GL_VERTEX_SHADER, vert_path);
    fragment_shader := compile_shader(GL_FRAGMENT_SHADER, frag_path);
    defer glDeleteShader(vertex_shader);
    defer glDeleteShader(fragment_shader);

    glAttachShader(program, vertex_shader);
    glAttachShader(program, fragment_shader);
    glLinkProgram(program);
    print(" success!\n");
    return program;
  }

  board_vs := create_vertex_set(vertex_indices, vertices);
  glBindVertexArray(board_vs.vao);
  board_program := compile_shader_program("board");

  // UNIFORMS
  glUseProgram(board_program);
  BoardShaderUniforms :: struct {
      white_color  := Color.{0.8, 0.8, 0.8};
      black_color  := Color.{0.4, 0.4, 0.4};

      border_color := Color.{0.0, 0.0, 0.0}; // black for now
      border_width :  float = 0.01; // in units of square width
  }
  board_look : BoardShaderUniforms;

  set_uniform(board_program, "blackColor",  board_look.black_color);
  set_uniform(board_program, "whiteColor",  board_look.white_color);
  set_uniform(board_program, "borderColor", board_look.border_color);
  set_uniform(board_program, "borderWidth", board_look.border_width);
  set_uniform(board_program, "squareDim",   square_dim);
  set_uniform(board_program, "t",  cast(float) 0.);
  print("Set uniforms successfully.\n");

  // ATTRIBUTES
  { // attributes for board_program
    glBindVertexArray(board_vs.vao);
    glUseProgram(board_program);
    // @note: need glVertexAttribIPointer when working with integer types, otherwise
    //        everything gets implicitly casted to float for some reason...
    offset : *Vertex : null; // giving OpenGL the right offsets (basically relative pointers)
    vsize : GLuint = size_of(Vertex);
    vi : u32 = 0;
    // The vertices and their data
    glEnableVertexAttribArray(vi);
    glVertexAttribPointer(vi, 2, GL_FLOAT, xx false, vsize, cast(*void) *offset.x);
    vi += 1;
    // The texture coordinates
    glEnableVertexAttribArray(vi);
    glVertexAttribPointer(vi, 2, GL_FLOAT, xx false, vsize, cast(*void) *offset.tx);
    vi += 1;
    // The indices of the square
    glEnableVertexAttribArray(vi);
    glVertexAttribIPointer(vi, 2, GL_INT, vsize, cast(*void) *offset.ix);
    vi += 1;
  }

  // PIECE program

  // TEXTURES
  // Reading in 1 texture takes 100 ms because OpenGL I guess.
  //   Doesn't matter as long as I only have one big texture map for all the pieces.

  // allocate buffers and shit
  piece_vs := create_vertex_set(piece_indices, piece_vertices);
  glBindVertexArray(piece_vs.vao);
  piece_program := compile_shader_program("piece");

  { // attributes for piece_program
    glBindVertexArray(piece_vs.vao); // @note: needed, and not too sure why
    glUseProgram(piece_program);

    // @note: need glVertexAttribIPointer when working with integer types, otherwise
    //        everything gets implicitly casted to float for some reason...
    offset : *PieceVertex : null; // giving OpenGL the right offsets (basically relative pointers)
    vsize : GLuint = size_of(PieceVertex);
    // Color
    glEnableVertexAttribArray(0);
    glVertexAttribIPointer(0, 1, GL_INT, vsize, cast(*void) *offset.color);
    // The type
    glEnableVertexAttribArray(1);
    glVertexAttribIPointer(1, 1, GL_INT, vsize, cast(*void) *offset.type);

    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2, 2, GL_FLOAT, xx false, vsize, cast(*void) *offset.pos);
    // position of piece on board
    glEnableVertexAttribArray(3);
    glVertexAttribPointer(3, 2, GL_FLOAT, xx false, vsize, cast(*void) *offset.tex);
  }

  texture : GLuint; // spritesheet of pieces
  #if MSAA {
    texture2: GLuint;
    fbo     : GLuint;
    rdo     : GLuint;
  }
  {
    width, height, nchannels : s32;

    // image_path :: "media/spritesheet.png";
    image_path :: "media/spritesheet2.png";

    print("Loading texture from '%'\n", image_path);
    data : *u8 = STB.stbi_load(image_path, *width, *height, *nchannels, 4);
    if (data == null) error("Unable to load image '%'\n", image_path);
    if (nchannels != 4) // expect rgba
      error("error loading '%': expected % color channels, got %\n", image_path, 4, nchannels);
    defer free(data);
    print("Successfully Loaded % x % image w/ % color channels into memory\n", width, height, nchannels);

    glGenTextures(1, *texture); // only one texture for now
    glBindTexture(GL_TEXTURE_2D, texture);

    // @note: internal format is what is used in the fragment shaders
    { // texture settings
      // Make mipmapped texture look better
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0); // no mipmaps, INCREASE IF NEED THEM;
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR); // bilinear
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); // bilinear
      // trilinear filtering only makes result look worse without additional anti-aliasing techniques for minification
    }

    // @note: this glTexImage2D is technically specifying the 0th mipmap level
    glTexImage2D  (GL_TEXTURE_2D, 0, GL_RGBA, xx width, xx height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    if glGetError() != GL_NO_ERROR error("There was an OpenGL texture error!\n");
    // glGenerateMipmap(GL_TEXTURE_2D); // doubles loading time, should be removed if mipmaps not needed


    // multisample code
    #if MSAA {
      // framebuffer
      glGenFramebuffers(1, *fbo);
      glEnable(GL_MULTISAMPLE);
      glBindFramebuffer(GL_FRAMEBUFFER, fbo);
      // texture
      glGenTextures(1, *texture2);
      glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, texture2);
      glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE, 4, GL_RGBA, xx width, xx height, xx true);
      check_gl_error();

      glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D_MULTISAMPLE, texture2, 0);
      check_framebuffer_status(); // errors if fbo is incomplete
    }

    print("Created a (%, %) texture\n", width, height);
    #if MSAA glBindFramebuffer(GL_FRAMEBUFFER, 0); // Goes back to the backbuffer
  }


  // game loop
  timer, total_timer : Timer;
  start_timer(*timer);
  start_timer(*total_timer);

  quit := false;
  sleep_milliseconds(10); // necessary for timer not to be set off
  stop_timer(*startup_timer);
  print("Startup took % ms\n", get_millis(*startup_timer));
  while !glfwWindowShouldClose(window) { // game loop
    defer nframes += 1;

    // Framerate calculation, done every few frames for a good average
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
      glUseProgram(board_program); // Need to be using board program, don't know why
      set_uniform(board_program, "t",  ftime);
    }

    // HANDLE INPUT
    glfwPollEvents(); // automatically invokes the key_callback() function

    // SIMULATE
    // @todo: make a board state update when there is a move registered

    // GRAPHICS
    width, height : s32;
    glfwGetWindowSize(window, *width, *height);

    if to_redraw_pieces {
      print("Redrawing pieces this frame\n");
      update_piece_vertices(*piece_vertices, *piece_indices); // updates vertices using board
      update_vs(*piece_vs, piece_indices, piece_vertices);    // reallocates and copies opengl objects.

      to_redraw_pieces = false;
    }

    // draw to backbuffer
    glClear(GL_COLOR_BUFFER_BIT);
    { // draw board
      // glClearColor(1, 1, 1, 0);
      glBindVertexArray(board_vs.vao); // have to bind every frame before drawing
      glUseProgram(board_program); // board_program is a shading board_program, specifically
      glDrawElements(GL_TRIANGLES, xx vertex_indices.count, GL_UNSIGNED_INT, xx 0);
      check_gl_error();
    }
    { // draw pieces
      glBindVertexArray(piece_vs.vao); // have to bind every frame before drawing
      glUseProgram(piece_program); // board_program is a shading board_program, specifically
      glDrawElements(GL_TRIANGLES, xx piece_indices.count, GL_UNSIGNED_INT, xx 0);
    }

    glfwSwapBuffers(window);
    reset_temporary_storage(); // allows us to allocate temporary stuff without fear every frame
  }
  glfwTerminate();
  print("Program exited and shut down correctly\n");
}
