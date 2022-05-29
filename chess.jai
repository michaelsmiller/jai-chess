// These definitions correspond to the arbitrary positioning in the spritesheet
PieceColor :: enum s32 {
  WHITE :: 0;
  BLACK :: 1;
  NONE  :: 2; // for providing a "neither" option in some functions
}

PieceType :: enum s32 {
  QUEEN  :: 0;
  KING   :: 1;
  BISHOP :: 2;
  KNIGHT :: 3;
  ROOK   :: 4;
  PAWN   :: 5;
  EMPTY  :: 6; // not important what the number is
}

Piece :: struct {
  color     : PieceColor = .NONE;
  type      : PieceType  = .EMPTY;
}
operator == :: (a : Piece, b : Piece) -> bool {
  return a.color == b.color && a.type == b.type;
}

EMPTY_PIECE : Piece : .{.NONE, .EMPTY};

Location :: Vector2(s32); // alias for location

Square :: struct {
  using piece : Piece = .{.NONE, .EMPTY};
  loc : Location      = .{0, 0};
}

empty :: (using square : Square) -> bool {
  return piece  == EMPTY_PIECE;
}

char_to_piece :: (char : u8) -> bool, Piece {
  p : Piece;
  capitalized : bool = char >= 65 && char <= 90;
  lowercased  : bool = char >= 97 && char <= 122;
  assert(is_alpha(char));
  if capitalized p.color = .WHITE;
  else p.color = .BLACK;

  val := to_lower(char);
  if val == {
    case #char "k"; p.type = .KING;
    case #char "r"; p.type = .ROOK;
    case #char "p"; p.type = .PAWN;
    case #char "n"; p.type = .KNIGHT;
    case #char "q"; p.type = .QUEEN;
    case #char "b"; p.type = .BISHOP;
    case; return false, p;
  }

  return true, p;
}

string_to_loc :: (s : string) -> bool, Vector2(s32) {
  assert(s.count >= 2);
  v : Vector2(s32);
  v.x = cast(s32) s[0] - cast(s32) (#char "a");
  v.y = cast(s32) s[1] - cast(s32) (#char "1");
  if v.x < 0 || v.y < 0 return false, v;
  return true, v;
}

algebra_to_piece_loc :: (s : string) -> bool, Piece, Location {
  p : Piece;
  loc : Location;
  if s.count < 3 return false, p, loc;

  success := true;
  success, p = char_to_piece(s[0]);
  if !success return false, p, loc;

  success, loc = string_to_loc(String.slice(s, 1, 2));
  return success, p, loc;
}

// @todo: write function to create piece from char_to_piece() and string_to_loc()

// holds entire state
Board_ :: struct(W : s32, H : s32) {
  turn    : PieceColor   = .WHITE;
  squares : [W*H] Square;
}
Board :: Board_(8, 8);


init_board :: (using board : *Board) {
  for *square, i : squares {
    using square;
    square.piece = EMPTY_PIECE;
    loc.x = cast(s32)i % board.H;
    loc.y = cast(s32)i / board.H;
  }
}

num_pieces :: (board : *Board, color : PieceColor = .NONE) -> s32 {
  count : s32 = 0;
  for square : board.squares
    if !empty(square) && (color == .NONE || square.piece.color == color)
      count += 1;
  return count;
}

place :: (using board : *Board, piece : Piece, loc : Location, check_exists : bool = true) -> bool {
  if piece == EMPTY_PIECE return false;

  i := loc.y * board.H + loc.x;
  if i < 0 || i >= board.H * board.W return false; // out of bounds check
  square := *squares[i];
  if !empty(square) && check_exists print("WARNING: piece % being overwritten!\n", square);
  square.piece = piece;
  // memcpy(square, *piece, size_of(Piece)); // should also work

  return true; // success
}

get :: (using board : *Board, loc : Location) -> Piece {
  i := loc.y * board.H + loc.x;
  return squares[i].piece;
}

set_position_from_file :: (board : *Board, filename : string) {
  print("Loading position from '%'\n", filename);
  init_board(board); // resets all squares
  s := File.read_entire_file(filename);
  lines := String.split(s, cast(u8)(#char "\n"));
  for line, i : lines {
    if line.count == 0 continue;

    success, p, loc := algebra_to_piece_loc(line);
    if !success {print("Error in converting piece '%'\n", line); exit(1);}
    place(board, p, loc, false);
  }
}

#scope_file

#import "Basic"; // for string stuff if we start doing that here
File :: #import "File"; // for reading files
String :: #import "String"; // for split
