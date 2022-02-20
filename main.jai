#import "Basic";

#import "glfw"; // GLFW for handling windows with the OS
#import "GL";   // OpenGL
File :: #import "File"; // for reading files
Math :: #import "Math"; // for lerp

// constants
vertex_shader_path :: "board.vert";
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

  #if T == float {
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

Vector2 :: struct($T : Type) {
  x, y : T;
}
Vector3 :: struct($T : Type) {
  x, y, z : T;
}
Color :: Vector3(float);

Vector4 :: struct($T : Type) {
  x, y, z, w : T;
}
make_vector2 :: inline (x : $T, y : T) -> Vector2(T) {
  v : Vector2(T);
  v.x = x;
  v.y = y;
  return v;
}
make_vector3 :: inline (x : $T, y : T, z: T) -> Vector3(T) {
  v : Vector3(T);
  v.x = x;
  v.y = y;
  v.z = z;
  return v;
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

  Vertex :: struct {
    x, y : float;        // coords
    tx, ty : float;      // texture coordinates
    is_white : int = 0;  // color of the square
  }

  make_vertex :: inline (x : float, y : float, tx : float, ty : float, is_white : int) -> Vertex {
    v : Vertex;
    v.x = x;
    v.y = y;
    v.tx = tx;
    v.ty = ty;
    v.is_white = is_white;
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
      color := ifx ((i%2==0) ^ (j%2==0)) then 0 else 1;

      itri1 := ivert * 6;
      itri2 := ivert * 6 + 3;
      vertices[itri1+0] = make_vertex(x  , y  , 0, 0, color);
      vertices[itri1+1] = make_vertex(x  , y+h, 0, 1, color);
      vertices[itri1+2] = make_vertex(x+w, y+h, 1, 1, color);

      vertices[itri2+0] = make_vertex(x+w, y+h, 1, 1, color);
      vertices[itri2+1] = make_vertex(x  , y  , 0, 0, color);
      vertices[itri2+2] = make_vertex(x+w, y  , 1, 0, color);
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

  { // Defines inputs to vertex shader
    offset : *Vertex : null; // giving OpenGL the right offsets (basically relative pointers)
    // Attribute 0 is the vertices and their data
    glVertexAttribPointer(0, 2, GL_FLOAT, xx false, size_of(Vertex), cast(*void) *offset.x);
    glEnableVertexAttribArray(0);
    // Attribute 1 is the texture coordinates
    glVertexAttribPointer(1, 2, GL_FLOAT, xx false, size_of(Vertex), cast(*void) *offset.tx);
    glEnableVertexAttribArray(1);
    // Attribute 2 is the color of the vertices
    glVertexAttribPointer(2, 1, GL_INT, xx false, size_of(Vertex), cast(*void) *offset.is_white);
    glEnableVertexAttribArray(2);
  }

  print("Compiling shaders...\n");
  program := glCreateProgram();
  vertex_shader := compile_shader(GL_VERTEX_SHADER, vertex_shader_path);
  fragment_shader := compile_shader(GL_FRAGMENT_SHADER, fragment_shader_path);
  glAttachShader(program, vertex_shader);
  glAttachShader(program, fragment_shader);
  glLinkProgram(program);
  glDeleteShader(vertex_shader); // only flags for deletion, doesn't take up time
  glDeleteShader(fragment_shader);
  glUseProgram(program); // need to use program to set uniforms in the shaders

  BoardShaderUniforms :: struct {
      white_color  := Color.{0.8, 0.8, 0.8};
      black_color  := Color.{0.4, 0.4, 0.4};

      border_color := Color.{0.0, 0.0, 0.0};
      border_width :  float = 0.01; // units of square width
  }
  board_uniforms : BoardShaderUniforms;

  { // set uniforms
    set_uniform(program, "blackColor",  board_uniforms.black_color);
    set_uniform(program, "whiteColor",  board_uniforms.white_color);
    set_uniform(program, "borderColor", board_uniforms.border_color);
    set_uniform(program, "borderWidth", board_uniforms.border_width);
  }
  
  // render loop
  nframes := 0;
  while !glfwWindowShouldClose(window) {
    nframes += 1;
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
  }

  glfwDestroyWindow(window);
  glfwTerminate();
  print("Program exited and shut down correctly\n");
}
