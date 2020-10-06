type t

val from_int : int -> int -> t

val proj_x : t -> int

val proj_y : t -> int

val eq : t -> t -> bool

val move : t -> t -> t

val string_of_position : t -> string
