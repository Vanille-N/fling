(** Tree exploration *)

type async_solver

(** Solve
@return an asynchronous solution promise *)
val solve : Rules.game -> async_solver

(** Each call to [step] advances the solver's computation.
@return the advancement of the computation
[    | None -> not done
     | Some(true) -> solved
     | Some(false) -> no solution]
*)
val step : async_solver -> bool option

(** Current state of the game
@return the internal state of the game being solved *)
val game : async_solver -> Rules.game

(** Advancement
@return the number of steps calculated *)
val count : async_solver -> int

(** Clear attempt and reset to initial state*)
val leave : async_solver -> unit

(** Check state
@return [true] iff a solution was found *)
val is_solved : async_solver -> bool
