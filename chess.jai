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
  squares : [W*H] Square;
  turn    : PieceColor   = .WHITE;
  move_history : [..] Move;
}
Board :: Board_(8, 8);
NUM_SQUARES :: Board.W * Board.H; // should be 64


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

  promotion_type := PieceType.EMPTY; // for promoting pawns only
}
operator == :: (m1 : Move, m2 : Move) -> bool {
  return m1.square1 == m2.square1 && m1.square2 == m2.square2;
}

other_color :: (color : PieceColor) -> PieceColor {
  if color == {
    case .WHITE; return .BLACK;
    case .BLACK; return .WHITE;
    case       ; return .NONE;
  }
}

just_promoted :: (using board : *Board) -> bool {
  if move_history.count == 0 return false;
  last_move := peek(board.move_history);
  using last_move;
  color := square1.piece.color;
  y     := square2.loc.y;

  return (color == .WHITE && y == Board.H-1) || (color == .BLACK && y == 0);
}

make_move :: (using board : *Board, using move : *Move) -> bool {
  i1 := square1.loc.x + square1.loc.y * board.W;
  i2 := square2.loc.x + square2.loc.y * board.W;
  // before any logic, change piece type if it is a pawn promoting
  piece := square1.piece;
  if move.promotion_type != .EMPTY {
    piece.type =  move.promotion_type;
  }

  squares[i1].piece = EMPTY_PIECE;
  squares[i2].piece = piece;


  // EN PASSANT
  diff := square2.loc - square1.loc;
  if piece.type == .PAWN && square2.piece == EMPTY_PIECE && Math.abs(diff.x) == 1 {
    loc := square1.loc;
    loc.x = square2.loc.x;
    i := loc.x + loc.y * board.W;
    squares[i].piece = EMPTY_PIECE;
  }

  // CASTLING
  else if piece.type == .KING && Math.abs(diff.x) == 2 {
    rook_loc := square1.loc;
    rook_loc.x = ifx diff.x > 0 then Board.W-1 else 0;
    rook := get(board, rook_loc);
    assert(rook.type == .ROOK); // sanity
    i := rook_loc.x + rook_loc.y * board.W;
    squares[i].piece = EMPTY_PIECE;

    // put the rook in the new place
    j := ifx diff.x > 0 then i1+1 else i1-1;
    squares[j].piece = rook;
  }

  board.turn = other_color(turn); // change colors
  array_add(*move_history, <<move);
  return true;
}

reverse_move :: (using board : *Board) -> bool {
  move := pop(*move_history);
  using move;

  i1 := square1.loc.x + square1.loc.y * board.W;
  i2 := square2.loc.x + square2.loc.y * board.W;
  // before any logic, change piece type back to pawn if it was promoting
  move_flags := get_move_flags(*move);
  piece := squares[i2].piece;
  if move_flags & .PROMOTION
    piece.type = .PAWN;

  squares[i1].piece = piece;
  squares[i2].piece = square2.piece;

  // EN PASSANT
  diff := square2.loc - square1.loc;
  if square1.piece.type == .PAWN && square2.piece == EMPTY_PIECE && Math.abs(diff.x) == 1 {
    loc := square1.loc;
    loc.x = square2.loc.x;
    i := loc.x + loc.y * board.W;
    squares[i].piece.type = .PAWN;
    squares[i].piece.color = other_color(square1.piece.color);
  }

  // CASTLING
  else if square1.piece.type == .KING && Math.abs(diff.x) == 2 {
    // assume checks already were done on correctness
    // get rook
    rook_loc := square1.loc;
    rook_loc.x = ifx diff.x > 0 then Board.W-1 else 0;
    i := rook_loc.x + rook_loc.y * board.W;

    j := ifx diff.x > 0 then i1+1 else i1-1;
    rook := squares[j].piece;
    assert(rook.type == .ROOK); // sanity
    squares[j].piece = EMPTY_PIECE;
    squares[i].piece = rook;
  }

  board.turn = other_color(turn); // change colors back
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


// CHESS RULES

MoveFlag :: enum u16 #specified {
  CAPTURE    :: 1;
  EN_PASSANT :: 2;
  CASTLE     :: 4;
  PROMOTION  :: 8;
}

// @todo: test if this works for multiple flags coming together
get_move_flags :: (using move : *Move) -> MoveFlag {
  flags : MoveFlag;
  // capture: if another piece is on that square then it's captured
  if square2.piece != EMPTY_PIECE flags |= MoveFlag.CAPTURE;

  // castling is when king moves 2 squares in any direction really
  dr := square2.loc - square1.loc;
  p  := square1.piece;
  if Math.abs(dr.x) == 2 && p.type == .KING flags |= MoveFlag.CASTLE;

  // promotion is when pawn is moving to either first square or last square
  loc2 := square2.loc;
  if p.type == .PAWN && (loc2.y == 0 || loc2.y == Board.H-1) flags |= MoveFlag.PROMOTION;

  // en passant is when a pawn moves diagonally to a square without capturing
  if p.type == .PAWN && (Math.abs(dr.x) == 1) && square2.piece == EMPTY_PIECE
    flags |= MoveFlag.EN_PASSANT;

  return flags;
}

is_under_attack :: (using board : *Board, square : *Square, color : PieceColor) -> bool {
  other := other_color(color);
  move : Move;
  move.square2 = <<square;

  for *sq : squares {
    if sq.loc == square.loc continue;
    piece := sq.piece;
    if piece.color != other continue; // empty squares and same color moves

    move.square1 = <<sq;
    if is_pseudo_legal(board, *move) return true;
  }
  return false;
}

is_in_check :: (using board : *Board, color : PieceColor) -> bool {
  for *square : squares {
    piece := square.piece;
    if piece.type == .KING && piece.color == color {
      return is_under_attack(board, square, color);
    }
  }
  return false;
}

is_checkmate :: (board : *Board) -> bool {
  color := board.turn;
  moves : [..] Move;
  defer array_free(moves);
  in_check := is_in_check(board, color);
  if in_check print("% in check: %\n", color, is_in_check(board, color));
  if !in_check return false;

  checkmate := !get_legal_moves(board, *moves);
  return checkmate;
}

is_draw :: (using board : *Board) -> bool {
  // @todo: find bug that causes promoted pawns to depromote for some reason
  legal_moves : [..] Move;
  defer array_free(legal_moves);
  has_moves := get_legal_moves(board, *legal_moves);
  // Stalemate
  if !is_checkmate(board) && !has_moves {
    print("Stalemate\n");
    return true;
  }

  // insufficient material to checkmate other king
  {
    using PieceType;
    piece_counts, other_piece_counts : [6] int;
    for *square : squares {
      if square.piece != EMPTY_PIECE {
        if square.piece.color == turn
          piece_counts[square.piece.type] += 1;
        else
          other_piece_counts[square.piece.type] += 1;
      }
    }
    if piece_counts[PieceType.PAWN] + piece_counts[PieceType.QUEEN] + piece_counts[PieceType.ROOK] == 0 {
      knights := piece_counts[PieceType.KNIGHT];
      bishops := piece_counts[PieceType.BISHOP];
      if knights == 0 && bishops == 0 return true;

      if knights + bishops == 1 {
        if other_piece_counts[PieceType.KNIGHT]
          +other_piece_counts[PieceType.QUEEN ]
          +other_piece_counts[PieceType.BISHOP]
          +other_piece_counts[PieceType.ROOK  ]
          +other_piece_counts[PieceType.PAWN  ]  == 0 {
            print("Insufficient mating material\n");
            return true;
          }
        // @note: purposefully neglecting to find opposing bishop and check if same
        //        color as our bishop, which would also be a draw.
      }
    }
  }

  // the other rules require looking back
  if move_history.count == 0 return false;

  // 50 move rule: both players make 50 moves without capturing pieces or moving a pawn
  no_pawns_or_captures := true;
  move_count := 0;
  for < *m : move_history {
    move_count += 1;
    if move_count >= 100 break;
    using m;
    if square1.piece.type == .PAWN || square2.piece != EMPTY_PIECE {
      no_pawns_or_captures = false;
      break;
    }
  }
  if no_pawns_or_captures && move_count >= 100 {
    print("Fifty move draw\n");
    return true;
  }

  // threefold repetition
  // strategy: unspool move_history and check for each position if the board was the same
  //           as the current board, and if all the same moves were possible.
  //           if this happened twice before the position is a draw.
  {
    position_count := 1;
    current_position : [Board.W*Board.H] Square = squares;
    current_turn := board.turn;
    past_moves : [..] Move;
    defer array_free(past_moves);
    past_legal_moves : [..] Move;
    defer array_free(past_legal_moves);

    while move_history.count > 0 {
      m := *move_history[move_history.count-1];
      array_add(*past_moves, <<m);
      reverse_move(board);
      if board.turn != current_turn continue;

      // check if board the same as now
      same_position := true;
      for i : 0..NUM_SQUARES {
        if board.squares[i] != current_position[i] {
          same_position = false;
          break;
        }
      }
      if !same_position continue;

      // check if all possible moves are the same then as they are now
      array_reset(*past_legal_moves);
      get_legal_moves(board, *past_legal_moves);
      if past_legal_moves.count != legal_moves.count continue;
      same_possible_moves := true;
      for i : 0..legal_moves.count-1 {
        if legal_moves[i] != past_legal_moves[i] {
          same_possible_moves = false;
          break;
        }
      }
      if same_possible_moves position_count += 1;
    }
    for < *m : past_moves {
      make_move(board, m);
    }

    if position_count >= 3 return true;
  }

  return false;
}

// @note: will return false for rooks involved in castling but that should be okay because
//        we don't need an accurate result in that scenario, probably
has_moved :: (using board : *Board, using square : *Square) -> bool {
  assert(piece == get(board, loc));
  // Checks if the piece currently on the square has ever moved to the square.
  for *move : move_history {
    p := move.square1.piece;
    to_loc := move.square2.loc;
    if p == piece && loc == to_loc return true;
  }
  return false;
}

has_just_moved :: (using board : *Board, using square : *Square) -> bool {
  assert(piece == get(board, loc));
  if board.move_history.count == 0 return false;
  // Checks if the piece currently on the square has ever moved to the square.
  move := peek(board.move_history);
  p := move.square1.piece;
  to_loc := move.square2.loc;
  return p == piece && loc == to_loc;
}

get_legal_moves :: (board : *Board, moves : *[..] Move, square : *Square = null) -> bool {
  pseudo_legal_moves : [..] Move;
  defer array_free(pseudo_legal_moves);
  if square == null
    get_pseudo_legal_moves(board, *pseudo_legal_moves);
  else
    get_pseudo_legal_moves(board, *pseudo_legal_moves, square);

  for *m : pseudo_legal_moves {
    if is_legal(board, m) array_add(moves, <<m);
  }
  return moves.count > 0;
}


get_pseudo_legal_moves :: (board : *Board, moves : *[..] Move) -> bool {
  count0 := moves.count;
  for *square : board.squares {
    if square.piece.color == board.turn
      get_pseudo_legal_moves(board, moves, square);
  }
  count := moves.count - count0;
  return count > 0;
}

get_pseudo_legal_moves :: (using board : *Board, moves : *[..] Move, square : *Square) -> bool {
  location  := square.loc;
  piece     := square.piece;
  color_direction := cast(s32)(ifx piece.color == .WHITE then 1 else -1);

  // @todo: Including this stopped an assert from triggering where get_legal_moves() was being
  //        called on an empty square, so really the source of that problem should be fixed instead.
  if piece == EMPTY_PIECE return false;

  in_bounds :: (loc : Location) -> bool {
    return loc.x >= 0 && loc.x < Board.W && loc.y >= 0 && loc.y < Board.H;
  }

  check_move_and_add :: (board : *Board, square1 : *Square, loc : Location, moves : *[..] Move,
                         allow_piece : bool, allow_no_piece := true, add_move := true) -> bool {
    if !in_bounds(loc) return false;
    square2 := get_square(board, loc);
    piece2  := square2.piece;
    if !allow_no_piece && (piece2 == EMPTY_PIECE || piece2.color == square1.piece.color) return false;
    if piece2 == EMPTY_PIECE || (allow_piece && piece2.color != square1.piece.color) {
      move : Move;
      move.square1 = <<square1;
      move.square2 =   square2;
      // if is_legal(board, *move) {
      if add_move array_add(moves, move);
      return true;
      // }
    }
    return false;
  }

  cardinal_directions : [4] Location : .[.{1,0}, .{0,1}, .{-1,0}, .{0,-1}];
  diagonal_directions : [4] Location : .[.{1,1}, .{-1,1}, .{-1,-1}, .{1,-1}];
  all_directions : [8] Location : .[.{1,1}, .{-1,1}, .{-1,-1}, .{1,-1},
                                         .{1,0}, .{0,1},  .{-1,0},  .{0,-1}];
  check_moves_in_direction :: (board : *Board, square : *Square,
                               directions : [] Location, moves : *[..] Move) {
    for direction : directions {
      // go in this direction until blocked
      done := false;
      loc := square.loc + direction;
      while check_move_and_add(board, square, loc, moves, true) {
        if get(board, loc) != EMPTY_PIECE break; // Can't skip over pieces
        loc += direction;
      }
    }
  }
  initial_count := moves.count;
  if piece.type == {
    case .PAWN;
      loc   := location;
      loc.y += color_direction; check_move_and_add(board, square, loc, moves, false);
      loc.x = location.x + 1; check_move_and_add(board, square, loc, moves, true, false);
      loc.x = location.x - 1; check_move_and_add(board, square, loc, moves, true, false);
      loc = location;
      if    (piece.color == .WHITE && location.y == 1)
         || (piece.color == .BLACK && location.y == Board.H-2) {
        loc.y += 2*color_direction;
        check_move_and_add(board, square, loc, moves, false);
      }

      // en passant
      deltas : [2] s32 : .[1, -1];
      for dx : deltas {
        loc = location;
        loc.x += dx;
        loc.y += color_direction;
        if !in_bounds(loc) || get(board, loc) != EMPTY_PIECE continue;

        loc.y = location.y;
        pawn_square := get_square(board, loc);
        if has_just_moved(board, *pawn_square) && pawn_square.piece.color == other_color(piece.color) {
          loc.y += color_direction;
          good := check_move_and_add(board, square, loc, moves, false);
        }
      }
    case .ROOK;
      check_moves_in_direction(board, square, cardinal_directions, moves);
    case .BISHOP;
      check_moves_in_direction(board, square, diagonal_directions, moves);
    case .KNIGHT;
      knight_offsets : [8] Location : .[
        .{1, 2}, .{2, 1}, .{2, -1}, .{1, -2},
        .{-1, 2}, .{-2, 1}, .{-2, -1}, .{-1, -2},
      ];
      for offset : knight_offsets
        check_move_and_add(board, square, location+offset, moves, true);
    case .QUEEN;
      check_moves_in_direction(board, square, all_directions, moves);
    case .KING;
      for direction : all_directions
        check_move_and_add(board, square, location+direction, moves, true);

      // castling
      if !has_moved(board, square) {
        for direction : cardinal_directions if direction.y == 0 {
          // 2. check if rook has moved
          rook_loc := location;
          rook_loc.x = ifx direction.x > 0 then Board.W-1 else 0;
          rook_square := get_square(board, rook_loc);
          if rook_square.type != .ROOK || has_moved(board, *rook_square) continue;

          loc := location+direction;
          valid := true;
          if valid check_move_and_add(board, square, location+(2*direction), moves, false);
        }
      }
    case; assert(false);
  }

  count := moves.count - initial_count;
  return count > 0;
}

is_legal :: (using board : *Board, using move : *Move) -> bool {
  if !is_pseudo_legal(board, move) return false;

  move_flags := get_move_flags(move);
  if move_flags & .CASTLE {
    direction := (square2.loc - square1.loc) / 2;
    rook_loc := square1.loc;
    rook_loc.x = ifx direction.x > 0 then Board.W-1 else 0;
    loc := square1.loc + direction;
    while loc != rook_loc {
      defer loc += direction;
      sq := get_square(board, loc);
      if is_under_attack(board, *sq, square1.piece.color) return false;
    }
  }

  // simulate move, check if king is in check, and then reverse move and return
  make_move(board, move);
  legal := !is_in_check(board, square1.piece.color);
  reverse_move(board);

  return legal;
}

is_pseudo_legal :: (using board : *Board, using move : *Move) -> bool {
  p1 := square1.piece;
  p2 := square2.piece;

  if p1 == EMPTY_PIECE return false; // there needs to be a piece moving
  if p1.color == p2.color return false; // Color can't take its own color
  if square1.loc == square2.loc return false;     // Can't move to same square

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

  // non-knights can only move on diagonal or cartesian axes
  if dx != 0 && dy != 0 && dx != dy return false;

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
    case .KING;
      if dx <= 1 && dy <= 1 return true; // normal king moves

      // castling
      // 0. check if dy == 0 and dx == 2
      if dy > 0 || dx != 2 return false;
      // 1. check if king has moved
      if has_moved(board, *square1) return false;
      // 2. check if there is a rook in the direction we are going
      rook_loc := loc2;
      rook_loc.x = ifx direction.x == 1 then Board.W-1 else 0;
      rook_square := get_square(board, rook_loc);
      rook := rook_square.piece;
      if rook.color != p1.color || rook.type != .ROOK return false;
      // 3. check if rook has moved
      if has_moved(board, *rook_square) return false;

      // 4. @todo: MAYYYYYBE check if in between squares are under attack?
      return true;

    case .PAWN;
      if direction.y != color_multiplier return false; // pawn can only move up for white and down for black
      // diagonal pawn move must be taking a piece
      if dx == 1 {
        if dy != 1 return false;
        if p2 != EMPTY_PIECE return true;

        // en passant
        loc := loc1;
        loc.x = loc2.x;
        square := get_square(board, loc);
        if square.piece.color != other_color(p1.color) || square.piece.type != .PAWN return false;
        return has_just_moved(board, *square);
      }
      else if dx != 0 return false;
      // dx == 0
      if dy > 2 return false;
      else if dy == 2
        return (p1.color == .WHITE && loc1.y == 1) || (p1.color == .BLACK && loc1.y == 6);
      else return true;

    case .QUEEN; return true;
    case .ROOK; return dx == 0 || dy == 0;
    case .BISHOP;  return dx == dy;
    case; assert(false); // should never reach this
  }

  return true;
}

#scope_file

#import "Basic"; // for string stuff if we start doing that here
File :: #import "File"; // for reading files
String :: #import "String"; // for split
Math :: #import "Math";
