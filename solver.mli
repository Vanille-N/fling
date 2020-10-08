type async_solver

(** [solve] doesn't really solve the problem.
  * instead, it returns an object that knows how to solve it *)
val solve : Rules.game -> async_solver

(** each call to [step] advances the solver's computation.
  *     | None -> not done
  *     | Some(true) -> solved
  *     | Some(false) -> no solution
  *)
val step : async_solver -> bool option

(** get the current state of the game *)
val game : async_solver -> Rules.game

(** get the number of steps made by the solver *)
val count : async_solver -> int
