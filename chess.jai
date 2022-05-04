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
  loc       : Vector2(s32); // position on [0,7]^2
}

empty :: (using p : Piece) -> bool {
  return type == .EMPTY;
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

algebra_to_piece :: (s : string) -> bool, Piece {
  p : Piece;
  if s.count < 3 return false, p;

  success := true;
  success, p = char_to_piece(s[0]);
  if !success return false, p;

  success, p.loc = string_to_loc(String.slice(s, 1, 2));
  return success, p;
}

// @todo: write function to create piece from char_to_piece() and string_to_loc()

// holds entire state
Board_ :: struct(W : s32, H : s32) {
  turn    : PieceColor   = .WHITE;
  squares : [W*H] Piece;
}
Board :: Board_(8, 8);


init_board :: (using board : *Board) {
  for *piece, i : squares {
    using piece;
    p : Piece;
    <<piece = p; // reset piece
    loc.x = cast(s32)i % board.H;
    loc.y = cast(s32)i / board.H;
  }
}

num_pieces :: (board : *Board, color : PieceColor = .NONE) -> s32 {
  count : s32 = 0;
  for piece : board.squares {
    if !empty(piece) && (color == .NONE || piece.color == color) count += 1;
  }
  return count;
}

place :: (using board : *Board, piece : Piece, check_exists : bool = true) -> bool {
  i := piece.loc.y * board.H + piece.loc.x;
  if piece.type == .EMPTY return false;
  if i < 0 || i >= board.H * board.W return false; // out of bounds check
  square := squares.data + i;
  if !empty(<<square) && check_exists print("WARNING: piece % being overwritten!\n", <<square);
  memcpy(square, *piece, size_of(Piece));

  return true; // success
}

get :: (using board : *Board, loc : Vector2(s32)) -> Piece {
  i := loc.y * board.H + loc.x;
  return squares[i];
}

set_position_from_file :: (board : *Board, filename : string) {
  print("Loading position from '%'\n", filename);
  init_board(board); // resets all squares
  s := File.read_entire_file(filename);
  lines := String.split(s, cast(u8)(#char "\n"));
  for line, i : lines {
    if line.count == 0 continue;

    success, p := algebra_to_piece(line);
    if !success {print("Error in converting piece '%'\n", line); exit(1);}
    place(board, p, false);
  }
}

#scope_file

#import "Basic"; // for string stuff if we start doing that here
File :: #import "File"; // for reading files
String :: #import "String"; // for split
