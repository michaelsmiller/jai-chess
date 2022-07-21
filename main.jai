#import "Basic";
// Window :: #import "Window_Creation"; // @todo: move back to GLFW for control over # samples/pixel
#import "glfw";
#import "GL";   // OpenGL, doesn't need a namespace because most functions are in a global struct anyway
File :: #import "File"; // for reading files

STB :: #import "stb_image"; // for reading pngs into memory

#load "math.jai"; // my simple math library
#load "util.jai"; // just timer code so far
#load "chess.jai"; // board/piece state and game logic

time_sample_rate : s64 : 100; // for framerate sampling
window_size :: Vector2(s32).{800, 800};

// Global state
//
toggle           := false;      // for debugging
to_redraw_pieces := false;      // Whether we need to recreate piece vertices and redraw this frame.
nframes          : s64 = 0;     // number of frames that have passed up to this point
framerate        : float = 0.;  // Written to and displayed on command

board            : Board;       // The internal game state, including move stack

square_selections : [NUM_SQUARES] s32; // The state of which squares have what selection
selection_changed := false;

InputState :: enum {
  DEFAULT;
  PROMOTE;
};
input_state : InputState = .DEFAULT; // The mode of inputting character by character

// End global state

// needs to be a macro to print the #procedure_name of the calling function
pprint :: (name : string, message : string, print_args : ..Any) #expand {
  print("% (%): ", name, #procedure_name());
  print(message, ..print_args);
}
error :: (message : string, print_args : ..Any) #expand {
  pprint("ERROR", message, ..print_args);
  glfwTerminate();
  exit(1);
}
warning :: (message : string, print_args : ..Any) #expand {
  pprint("WARNING", message, ..print_args);
}

// callbacks
do_end_of_turn_logic :: () {
  if is_checkmate(*board) print("CHECKMATE: % wins!\n", other_color(board.turn));
  if is_draw(*board) print("DRAW: everybody's a winner (empyrrhically)!");
  print("% to move\n", board.turn);
}

mouse_button_callback :: (window : *GLFWwindow) #c_call {
  new_context : Context;
  push_context new_context {
    if true {
      x, y : float64; // pixels, graphically arranged
      glfwGetCursorPos(window, *x, *y);
      y = window_size.y - 1 - y; // make coordinates cartesian

      // @todo: make window_size a mutable variable that updates with the changing window
      pixels_per_square : Vector2(s32);
      pixels_per_square.x = window_size.x / board.W;
      pixels_per_square.y = window_size.y / board.H;

      location : Location;
      location.x = (cast(s32)x) / pixels_per_square.x;
      location.y = (cast(s32)y) / pixels_per_square.y;

      i := location.x + board.W * location.y;
      if square_selections[i] != 1 {
        // deselect all squares other than the new one, and mark if one was selected
        prev : Square;
        for j : 0..NUM_SQUARES-1 {
          curr := square_selections[j];
          if curr == 1 prev = board.squares[j];
          if curr > 0  square_selections[j] = 0;
        }
        // This represents a movement
        if prev.piece != EMPTY_PIECE && prev.piece.color == board.turn {
          // @todo: maybe create a global queued move, and after handling inputs we perform the move
          //        in the game loop itself.
          //        unless it's a promotion, in which case we change global state and wait until input
          curr := board.squares[i];
          m : Move;
          m.square1 = prev;
          m.square2 = curr;
          if is_legal(*board, *m) {
            make_move(*board, *m);
            to_redraw_pieces = true;
            move_flags := get_move_flags(*m);
            if move_flags & .PROMOTION {
              print("% promoting a pawn!\n", other_color(board.turn));
              print("Please enter the desired piece character:\n");
              input_state = .PROMOTE;
            }
            else {
              do_end_of_turn_logic();
            }

          }
          else print("Illegal move!\n");
        }
        // Just selecting a square
        else {
          square_selections[i] = 1;
          // if this square has a piece display all the possible moves
          // but only if it is that piece's turn
          square1 := board.squares[i];
          if square1.piece.color == board.turn {
            moves : [..] Move;
            get_legal_moves(*board, *moves, *square1);
            for *move : moves {
              loc := move.square2.loc;
              j := loc.x + board.W * loc.y;
              square_selections[j] = 2; // secondary
            }
          }
        }
      }
      else {// square_selections[i] = 0;
        for j : 0..NUM_SQUARES-1 {
          curr := square_selections[j];
          if curr > 0  square_selections[j] = 0;
        }
      }
      selection_changed = true; // marks for flushing the uniform this frame
    }
  }
}

key_callback :: (window : *GLFWwindow, key : s32, scancode : s32, action : s32, mods : s32) #c_call {
  new_context : Context;
  push_context new_context {
    if action == GLFW_RELEASE || action == GLFW_REPEAT return;

    // @note: important that this be as early as possible, so that one can always quit
    if key == GLFW_KEY_ESCAPE {
      glfwSetWindowShouldClose(window, GLFW_TRUE);
      return;
    }
    if input_state == .PROMOTE {
      s := to_string(glfwGetKeyName(key, scancode));
      if s.count != 1 return;
      c := s[0];
      // uppercase if shift pressed
      success, piece := char_to_piece(c);
      if !success return;

      piece_type := piece.type;
      if piece_type == .PAWN || piece_type == .KING {
        print("Fuck you and your whole life!\n");
        return;
      }
      last_move := *board.move_history[board.move_history.count-1];
      assert(last_move.square1.piece.type == .PAWN);
      last_move.promotion_type = piece_type;
      loc := last_move.square2.loc;
      i := loc.x + loc.y * Board.W;
      board.squares[i].piece.type = piece_type;

      print("% Pawn promoted to %\n", board.turn, board.squares[i].piece.type);
      do_end_of_turn_logic();
      to_redraw_pieces = true;
      input_state = .DEFAULT;
      return;
    }

    if key == GLFW_KEY_ENTER {
      toggle = !toggle;
      print("Toggle boolean is now %\n", toggle);
    }
    else if key == GLFW_KEY_SPACE {
      color := board.turn;
      other := other_color(color);
      print("FOR DEBUGGING: changing color to move: (% -> %)\n", color, other);
      board.turn = other;
    }
    else if key == GLFW_KEY_F {
      if nframes > time_sample_rate print("Respects paid: % fps\n", cast(int)framerate);
    }
    else if key == GLFW_KEY_U {
      can_undo := board.move_history.count > 0;
      if !can_undo {
        print("Cannot undo because there have been no moves!\n");
        return;
      }
      move := peek(board.move_history);
      print("Undoing last move: %\n", move);
      reverse_move(*board);
      to_redraw_pieces = true;
      // reset selections because it looks bad right now!
      for i : 0..NUM_SQUARES-1 square_selections[i] = 0;
      selection_changed = true;

    }
    else { // print the key pressed
      builder : String_Builder;
      init_string_builder(*builder, 4);
      defer free_buffers(*builder);
      if mods & GLFW_MOD_CONTROL append(*builder, "Ctrl-");
      if mods & GLFW_MOD_ALT     append(*builder, "Alt-");
      if mods & GLFW_MOD_SHIFT   append(*builder, "Shift-");
      append(*builder, tprint("%\n", to_string(glfwGetKeyName(key, scancode))));
      print("Pressed: ");
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

compile_shader :: (shader_type : u32, source_path : string) -> u32 {
  using gl;
  shader := glCreateShader(shader_type);
  shader_text, file_success := File.read_entire_file(source_path, true);
  defer free(shader_text);
  if !file_success error("There was an error reading the shader: %\n", source_path);

  _glShaderSource(shader, shader_text);
  glCompileShader(shader);
  compile_success : s32;
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

  if !glfwInit() error("glfwInit() failed");
  NSAMPLES : s32 : 4;
  glfwWindowHint(GLFW_SAMPLES, NSAMPLES); // for super-sampling!
  window := glfwCreateWindow(window_size.x, window_size.y, "Chess", null, null);
  if !window error("Couldn't open GLFW window.");
  glfwMakeContextCurrent(window);

  // callbacks
  glfwSwapInterval(1);

  print("Successfully created window of size % pixels\n", window_size);
  {
    ns := glfwGetWindowAttrib(window, GLFW_SAMPLES);
    if ns != NSAMPLES
      warning("Number of samples is % instead of %, system to blame probably\n", ns, NSAMPLES);
  }

  // Should correspond exactly with what is fed to vertex buffer
  // @todo: make some functions to easily load into vertex buffer given fewer inputs
  SquareVertex :: struct {
    x, y : float;        // coords
    tx, ty : float;      // texture coordinates
    ix, iy : s32;      // index of what square this is on
  }

  make_vertex :: inline (x : float, y : float, tx : float, ty : float, ix : s32, iy : s32) -> SquareVertex {
    v : SquareVertex;
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

  vertices       : [4*nsquares] SquareVertex; // 4 vertices per square
  vertex_indices : [6*nsquares] u32; // 2 triangles per square, each has 3 vertices
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

      ix := cast(s32) i;
      iy := cast(s32) (square_dim.y - j - 1); // flip y axis back for square indices
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
  // set_position_from_file(*board, "positions/castle.chess");
  // set_position_from_file(*board, "positions/promotion.chess");

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
  // @note: really this is the graphics state, as opposed to game state
  update_piece_vertices :: (piece_vertices : *[..] PieceVertex, piece_indices : *[..] u32 ) {
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

  // UNIFORMS
  BoardShaderUniforms :: struct {
      white_color  := Color.{0.8, 0.8, 0.8};
      black_color  := Color.{0.4, 0.4, 0.4};

      border_color := Color.{0.0, 0.0, 0.0}; // black for now
      border_width :  float = 0.01; // in units of square width

      selection_color1 := Color.{1.0, 1.0, 0.0}; // yellow
      selection_color2 := Color.{1.0, 0.0, 1.0}; // purple
      selection_width : float = 0.04;
  }
  board_look : BoardShaderUniforms;

  print("Set uniforms successfully.\n");


  // TEXTURES
  // Reading in 1 texture takes 100 ms because OpenGL I guess.
  //   Doesn't matter as long as I only have one big texture map for all the pieces.

  texture : u32; // spritesheet of pieces
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
    print("Created a (%, %) texture\n", width, height);
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
    }

    // HANDLE INPUT
    glfwPollEvents(); // automatically invokes the key_callback() function

    // SIMULATE
    // @todo: make a board state update when there is a move registered

    // GRAPHICS
    width, height : s32;
    glfwGetWindowSize(window, *width, *height);

    if to_redraw_pieces {
      // @todo
      to_redraw_pieces = false;
    }

    // draw to backbuffer
    // @todo

    glfwSwapBuffers(window);
    reset_temporary_storage(); // allows us to allocate temporary stuff without fear every frame
  }
  glfwTerminate();
  print("Program exited and shut down correctly\n");
}
