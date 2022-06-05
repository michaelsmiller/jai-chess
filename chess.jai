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

// @note: needs to be reversible, so this information is necessary
Move :: struct {
  square1 : Square;
  square2 : Square;
}

other_color :: (color : PieceColor) -> PieceColor {
  if color == {
    case .WHITE; return .BLACK;
    case .BLACK; return .WHITE;
  }
  return .NONE;
}

move :: (using board : *Board, using move : *Move, check : bool = false) -> bool {
  i1 := square1.loc.x + square1.loc.y * board.W;
  i2 := square2.loc.x + square2.loc.y * board.W;
  squares[i1].piece = EMPTY_PIECE;
  squares[i2].piece = square1.piece;
  board.turn = other_color(turn); // change colors
  return true;
}

get :: inline (using board : *Board, loc : Location) -> Piece {
  i := loc.y * board.H + loc.x;
  return squares[i].piece;
}

get_square :: inline (using board : *Board, loc : Location) -> Square {
  square: Square;
  square.loc = loc;
  square.piece = get(board, loc);
  return square;
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

// Chess rules

get_pseudo_legal_moves :: (using board : *Board, square : *Square, moves : *[..] Move) -> bool {
  location  := square.loc;
  piece     := square.piece;
  direction := cast(s32)(ifx piece.color == .WHITE then 1 else -1);

  in_bounds :: (loc : Location) -> bool {
    return loc.x >= 0 && loc.x < Board.W && loc.y >= 0 && loc.y < Board.H;
  }

  check_move_and_add :: (board : *Board, square1 : *Square, loc : Location,
                             moves : *[..] Move, allow_piece : bool, allow_no_piece : bool = true) -> bool {
    if !in_bounds(loc) return false; // @todo: remove this check if done before this function
    square2 := get_square(board, loc);
    piece2  := square2.piece;
    if !allow_no_piece && (piece2 == EMPTY_PIECE || piece2.color == square1.piece.color) return false;
    if piece2 == EMPTY_PIECE || (allow_piece && piece2.color != square1.piece.color) {
      move : Move;
      move.square1 = <<square1;
      move.square2 =   square2;
      array_add(moves, move);
      return true;
    }
    return false;
  }

  initial_count := moves.count;
  if piece.type == {
    case .PAWN;
      loc   := location;
      loc.y += direction; check_move_and_add(board, square, loc, moves, false);
      loc.x = location.x + 1; check_move_and_add(board, square, loc, moves, true, false);
      loc.x = location.x - 1; check_move_and_add(board, square, loc, moves, true, false);
      loc = location;
      if    (piece.color == .WHITE && location.y == 1)
         || (piece.color == .BLACK && location.y == Board.H-2) {
        loc.y += 2*direction; check_move_and_add(board, square, loc, moves, false);
      }
    case .ROOK;
    case .BISHOP;
    case .KNIGHT;
    case .QUEEN;
    case .KING;
  }
  count := moves.count - initial_count;
  if count > 0 {
    print("Found and added % moves.\n", count);
  }
  else print("Found 0 legal moves.\n");

  return count > 0;
}

is_pseudo_legal :: (using board : *Board, using move : *Move) -> bool {
  p1 := square1.piece;
  p2 := square2.piece;
  // print("% -> %\n  % to move\n", square1, square2, board.turn);

  if p1 == EMPTY_PIECE return false; // there needs to be a piece moving
  if p1.color != turn  return false; // needs to be the piece's color's turn
  if p1.color == p2.color return false; // Color can't take its own color

  loc1 := square1.loc;
  loc2 := square2.loc;
  diff := loc2 - loc1;
  dx := Math.abs(diff.x);
  dy := Math.abs(diff.y);
  direction := diff / max(dx, dy);
  color_multiplier := ifx p1.color == .WHITE then 1 else -1;

  // deal with knight first to think of others as rows, columns, and diagonal movements
  if p1.type == .KNIGHT
    return (dx == 1 && dy == 2) || (dx == 2 && dy == 1);

  if square1.loc == square2.loc return false;     // Can't move to same square
  if dx != 0 && dy != 0 && dx != dy return false; // Either diagonals or on a main axis

  // checks every space between 2 squares, exclusive, for the existence of a piece
  piece_between :: (using board : *Board, loc1 : Location, loc2 : Location) -> bool {
    diff := loc2 - loc1;
    n := max(Math.abs(diff.x), Math.abs(diff.y));
    if n == 1 return false;

    assert(n != 0);
    direction := diff / n; // The quantum of change
    v := loc1 + direction;
    while v != loc2 {
      if get(board, v) != EMPTY_PIECE return true;
      v = v + direction;
    }
    return false;
  }

  if piece_between(board, loc1, loc2) return false; // check for piece in the way

  if p1.type == {
    case .KING; return dx <= 1 && dy <= 1;
    case .PAWN;
      if direction.y != color_multiplier return false; // pawn can only move up for white and down for black
      // diagonal pawn move must be taking a piece
      if dx == 1 {
        if dy != 1 return false;
        return p2 != EMPTY_PIECE;
      }
      else if dx != 0 return false;
      // dx == 0
      if dy > 2 return false;
      else if dy == 2
        return (p1.color == .WHITE && loc1.y == 1) || (p1.color == .BLACK && loc1.y == 6);
      else return true;

    case .QUEEN; #through;
    case .ROOK;  #through;
    case .BISHOP;  return true;
    case; assert(false); // should never reach this
  }

  return true;
}

#scope_file

#import "Basic"; // for string stuff if we start doing that here
File :: #import "File"; // for reading files
String :: #import "String"; // for split
Math :: #import "Math";
