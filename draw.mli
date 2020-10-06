(** [init_window ()] is called to initialize the window *)
val init_window : unit -> unit

(** [close_window ()] is called when the player wants to leave *)
val close_window : unit -> unit

(** [draw_ball ~select:b ball] draw the ball [ball] on the window.
    Moreover, if b is true, then print red circle around the ball [ball] *)
val draw_ball : ?select:bool -> Rules.ball -> unit

(** [draw_game width height game] draw a grid of size width * height and
    draw the balls of the game [game] on the grid *)
val draw_game : int -> int -> Rules.game -> unit

(** [draw_menu func_list] shows a menu that correspond to the possible choices of the player *)
val draw_menu : (string * 'a) list -> unit

(** [position_of_coord x y] returns the position on the grid of the mouse coordinates [x] and [y] *)
val position_of_coord : int -> int -> Position.t

(** [ready b] allows to make the difference between an old game and a new game. when [b] is true, then it is the beginning of a new game. *)
val ready : bool -> unit

(** [draw_string s] draws the string [s] at the top of the board *)
val draw_string : string -> unit
