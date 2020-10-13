(** Game rules : interface types, logic, some utilities *)

type direction = Up | Right | Down | Left | Stay

type ball

type move

type game

(** Grid width *)
val max_x: int

(** Grid height *)
val max_y: int

(** Initialize a new ball
@return a new ball identified by its id *)
val make_ball : int -> ball

(** Initialize a new game from balls and their positions
@return the newly created game *)
val new_game : (ball * Position.t) list -> game

(** Compare balls
@return [true] iff the balls are equal independently of their position *)
val eq_ball : ball -> ball -> bool

(** Create a user move
@return a new move applied to a given ball, in a given direction *)
val make_move : ball -> direction -> move

(** Update game after user move
@return a game where the move has been applied as well as the list of all updates made *)
val apply_move : game -> move -> game * (ball * Position.t * Position.t) list

(** Update game after undo
@return a game where the last move has been rolled back and a list of updates *)
val undo_move : game -> game * (ball * Position.t * Position.t) list

(** Update game after redo
@return a game where the last undo has been re-applied and a list of updates *)
val redo_move : game -> game * (ball * Position.t * Position.t) list

(** List allowed moves
@return a list of valid moves for the current game *)
val moves : game -> move list

(** List allowed moves with a ball
@return a list of valid moves starting with the given ball *)
val moves_ball : game -> ball -> move list

(** List balls
@return all balls still on the board *)
val get_balls : game -> ball list

(** Probe for balls
@return [true] iff the given game has a ball at the given position *)
val is_ball : game -> Position.t -> bool

(** Extract ball
@return the ball that is on the given position
@raise Not_found if there is none *)
val ball_of_position : game -> Position.t -> ball

(** Locate a ball
@return the position of the ball
@raise Not_found if ball does not exist *)
val position_of_ball : game -> ball -> Position.t

(** Create independent clone of the board
@return a fresh game *)
val deep_copy : game -> game

(** Extract a move's internals
@return the direction of the move *)
val direction_of_move : move -> direction

(** Look for moves to undo
@return [true] iff some move can be undone *)
val has_undo : game -> bool

(** Look for moves to redo
@return [true] iff some move can be redone *)
val has_redo : game -> bool

(** Win
@return [true] iff the user has won *)
val is_win : game -> bool

(** End of game
@return [true] iff no move can be played *)
val is_blocked : game -> bool

(** Save to file
@return success or failure information *)
val write_game : string -> game -> (unit, string) result

(** Load from file
@return game or failure information *)
val load_game : string -> (Position.t list, string) result

(** Forget redo *)
val clear_redo : game -> unit

(** Check validity of position
@return [true] iff the position is valid *)
val is_inside : Position.t -> bool

(** Make position valid
@return position adjusted to be in bounds *)
val closest_inside : Position.t -> Position.t
