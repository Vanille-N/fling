type direction = Up | Right | Down | Left | Stay


type ball

type move

type game

(** export grid dimensions *)
val max_x: int
val max_y: int

(** [make_ball id pos] returns a new ball idendified as [id] at position [pos] *)
val make_ball : int -> ball

(** [new_game ball_list] returns a new game form a list of balls [ball_list] *)
val new_game : (ball * Position.t) list -> game

(** [eq_ball ball ball'] returns true if and only if ball and ball' are equals
    indenpendetly from their position since balls can move *)
val eq_ball : ball -> ball -> bool

(** [make_move b d] returns a new move from a ball [b] and a direction [d] *)
val make_move : ball -> direction -> move

(** [apply_move game move] returns a new game where [move] has been applied to [game] *)
val apply_move : game -> move -> game * (ball * Position.t * Position.t) list

(** [undo_move game] rolls back the last move. Repeatable. *)
val undo_move : game -> game * (ball * Position.t * Position.t) list

(** [redo_move game] re-applies the last undone move. Repeatable *)
val redo_move : game -> game * (ball * Position.t * Position.t) list

(** [moves game] returns all the valid moves possible for [game] *)
val moves : game -> move list

(** [moves_ball game ball] returns all the valid moves for [game] that involve [ball] *)
val moves_ball : game -> ball -> move list

(** [get_balls game] returns the current list of ball on the [game] *)
val get_balls : game -> ball list

(** [is_ball pos] returns true if and only if their is a ball on the position [pos] *)
val is_ball : game -> Position.t -> bool

(** [ball_of_position game pos] returns the ball that is on the position [pos]. Fail if there is none *)
val ball_of_position : game -> Position.t -> ball

(** [position_of_ball ball] returns the position of the ball [ball] *)
val position_of_ball : game -> ball -> Position.t

(** [game] is not immutable, we need a way to deep copy it *)
val deep_copy : game -> game

(** useful to display the allowed directions *)
val direction_of_move : move -> direction

(** is there a previous move ? *)
val has_undo : game -> bool

(** is there a next move ? *)
val has_redo : game -> bool

(** did we win ? *)
val is_win : game -> bool

(** is the game over ? *)
val is_blocked : game -> bool

(** write game to channel. First input specifies the format to use *)
val write_game : string -> game -> (unit, string) result

(** load game from file *)
val load_game : string -> (Position.t list, string) result

(** forget about all moves that were undone *)
val clear_fwd : game -> unit

(** is the position inside the grid ? *)
val is_inside : Position.t -> bool

(** determine which position inside the grid is closest to this one *)
val closest_inside : Position.t -> Position.t
