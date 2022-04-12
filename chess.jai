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

// holds entire state
Board_ :: struct(W : s32, H : s32) {
  turn    : PieceColor   = .WHITE;
  squares : [W*H] Piece;
}
Board :: Board_(8, 8);


init_board :: () -> Board {
  using board : Board;
  for *piece, i : squares {
    using piece;
    loc.x = cast(s32)i % board.H;
    loc.y = cast(s32)i / board.H;
  }
  return board;
}

num_pieces :: (board : *Board, color : PieceColor = .NONE) -> s32 {
  count : s32 = 0;
  for piece : board.squares {
    if !empty(piece) && (color == .NONE || piece.color == color) count += 1;
  }
  return count;
}

place :: (using board : *Board, piece : Piece, check_exists : bool = true) {
  i := piece.loc.y * board.H + piece.loc.x;
  square := squares.data + i;
  if !empty(<<square) && check_exists print("WARNING: piece % being overwritten!\n", <<square);
  memcpy(square, *piece, size_of(Piece));
}

get :: (using board : *Board, loc : Vector2(s32)) -> Piece {
  i := loc.y * board.H + loc.x;
  return squares[i];
}

print_board :: (using board : *Board) {
  print("");
}

#scope_file

#import "Basic"; // for string stuff if we start doing that here
