(** Coordinates abstraction *)

type t

(** Initialize a new position *)
val of_ints : int -> int -> t

(** Extract first coordinate *)
val proj_x : t -> int

(** Extract second coordinate *)
val proj_y : t -> int

(** Check if two positions are the same *)
val eq : t -> t -> bool

(** Vector addition on positions *)
val move : t -> t -> t

(** Pretty-print coordinates *)
val to_string : t -> string
