type t

val of_int : int -> int -> t

val proj_x : t -> int

val proj_y : t -> int

val eq : t -> t -> bool

val move : t -> t -> t

val to_string : t -> string
