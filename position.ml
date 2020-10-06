type t = int * int

let from_int x y = (x,y)

let proj_x = fst

let proj_y = snd

let eq x y = x = y

let move (x,y) (x',y') = (x+x',y+y')

let string_of_position (x,y) = Printf.sprintf "(%s,%s)" (string_of_int x) (string_of_int y)
