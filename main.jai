#import "Basic";

#import "glfw"; // GLFW for handling windows with the OS
#import "GL";   // OpenGL
File :: #import "File"; // for reading files
Math :: #import "Math"; // for lerp

#load "math.jai"; // my math library

// constants
vertex_shader_path   :: "board.vert";
fragment_shader_path :: "board.frag";

error :: (message : string, print_args : ..Any) {
  print(message, ..print_args);
  glfwTerminate(); // should be fine even if glfwInit has not been called yet
  exit(1);
}

error_callback :: (error : s32, description: *u8) #c_call {
  new_context : Context;
  push_context new_context {
    print("WTF!: %\n", to_string(description));
  }
}

key_callback :: (window : *GLFWwindow, key: s32, scancode: s32, action: s32, mods: s32) #c_call {
  if key == GLFW_KEY_ESCAPE && action == GLFW_PRESS {
    glfwSetWindowShouldClose(window, GLFW_TRUE);
  }
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
  glfwSetErrorCallback(error_callback);
  if !glfwInit() error("Failed to start GLFW...\n");
  print("Booted up GLFW!\n");

  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
  window_size : Vector2(s32) = .{800, 800};
  window := glfwCreateWindow(window_size.x, window_size.y, "Chess", null, null);
  if !window error("Couldn't open window!");

  glfwSetKeyCallback(window, key_callback);
  glfwMakeContextCurrent(window);
  gl_load(*gl, glfwGetProcAddress); // Makes OpenGL available
  using gl;
  glfwSwapInterval(1); // set to 0 if fps too low, supposed to prevent screen tearing

  version_major, version_minor := gl_get_version();
  print("Loaded OpenGL function pointers, using version: %.%\n", version_major, version_minor);

  Vertex :: struct {
    x, y : float;        // coords
    tx, ty : float;      // texture coordinates
    is_white : GLint;     // color of the square
    ix, iy : GLint;      // index of what square this is on
  }

  make_vertex :: inline (x : float, y : float, tx : float, ty : float, is_white : GLint, ix : GLint, iy : GLint) -> Vertex {
    v : Vertex;
    v.x = x;
    v.y = y;
    v.tx = tx;
    v.ty = ty;
    v.is_white = is_white;
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
      x  := Math.lerp(-1., 1., xfrac);
      y  := Math.lerp(-1., 1., yfrac);
      w  := 2 / cast(float) nsquares_width;
      h  := 2 / cast(float) nsquares_height;
      color : GLint = cast(GLint) ifx ((i%2==0) ^ (j%2==0)) then 0 else 1;
      other_color := ifx color == 0 then 1 else 0; // for fun :)


      ix := cast(GLint) i;
      iy := cast(GLint) (nsquares_height - j - 1); // flip y axis back for square indices
      // print("ix = %, iy = %\n", ix, iy);
      itri1 := ivert * 6;
      itri2 := ivert * 6 + 3;
      vertices[itri1+0] = make_vertex(x  , y  , 0, 0, color, ix, iy); // first triangle
      vertices[itri1+1] = make_vertex(x  , y+h, 0, 1, color, ix, iy);
      vertices[itri1+2] = make_vertex(x+w, y+h, 1, 1, color, ix, iy);
      vertices[itri2+0] = make_vertex(x+w, y+h, 1, 1, color, ix, iy); // second triangle
      vertices[itri2+1] = make_vertex(x  , y  , 0, 0, color, ix, iy);
      vertices[itri2+2] = make_vertex(x+w, y  , 1, 0, color, ix, iy);
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
  // board_look.border_color = 0.5*(board_look.black_color + board_look.white_color);

  // UNIFORMS
  {
    set_uniform(program, "blackColor",  board_look.black_color);
    set_uniform(program, "whiteColor",  board_look.white_color);
    set_uniform(program, "borderColor", board_look.border_color);
    set_uniform(program, "borderWidth", board_look.border_width);
    set_uniform(program, "squareDim",   Vector2(s32).{nsquares_width, nsquares_height});
  }

  // ATTRIBUTES
  {
    // @note: need glVertexAttribIPointer when working with integer types, otherwise
    //        everything gets implicitly casted to float
    offset : *Vertex : null; // giving OpenGL the right offsets (basically relative pointers)
    vsize : GLuint = size_of(Vertex);
    // The vertices and their data
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, xx false, vsize, cast(*void) *offset.x);
    // The texture coordinates
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, xx false, vsize, cast(*void) *offset.tx);
    // The color of the vertices
    glEnableVertexAttribArray(2);
    glVertexAttribIPointer(2, 1, GL_INT, vsize, cast(*void) *offset.is_white);
    // The indices of the square
    glEnableVertexAttribArray(3);
    glVertexAttribIPointer(3, 2, GL_INT, vsize, cast(*void) *offset.ix);
  }
  
  // render loop
  nframes := 0;
  while !glfwWindowShouldClose(window) {
    nframes += 1;
    // if nframes % 100 == 0 && nframes > 0 print("On frame %\n", nframes);
    width, height : s32;
    glfwGetFramebufferSize(window, *width, *height);
    glViewport(0, 0, xx width, xx height);

    glClear(GL_COLOR_BUFFER_BIT);

    // draw to backbuffer
    glUseProgram(program); // program is a shading program, specifically
    glBindVertexArray(vao); // have to bind every frame before drawing
    glDrawArrays(GL_TRIANGLES, 0, vertices.count);

    glfwSwapBuffers(window);
    glfwPollEvents();
    reset_temporary_storage(); // allows us to allocate temporary stuff without fear every frame
  }

  glfwDestroyWindow(window);
  glfwTerminate();
  print("Program exited and shut down correctly\n");
}
