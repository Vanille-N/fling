(** Tree exploration *)

type async_solver

(** [solve] doesn't really solve the problem. Instead, it returns an object that knows how to solve it *)
val solve : Rules.game -> async_solver

(** Each call to [step] advances the solver's computation.
@return the advancement of the computation
[    | None -> not done
     | Some(true) -> solved
     | Some(false) -> no solution]
*)
val step : async_solver -> bool option

(** Get the current state of the game being solved *)
val game : async_solver -> Rules.game

(** Get the number of steps made by the solver *)
val count : async_solver -> int

(** Clear moves attempted by the solver *)
val leave : async_solver -> unit

(** Did we find a solution ? *)
val is_solved : async_solver -> bool
