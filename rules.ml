type direction = Up | Right | Down | Left

module Sint = Set.Make(
  struct
    let compare = Stdlib.compare
    type t = int
  end )

type ball = {
    id: int;
    mutable pos: Position.t;
}

type move = {
    ball: ball;
    dir: direction;
}

type game = {
    balls: ball array;
    active: Sint.t;
}

let make_ball id p =
    { id=id; pos=p }

let new_game bs =
    (* use an array for better access *)
    let balls = Array.of_list bs in
    (* start with all balls active *)
    let active = Sint.of_list (List.init (Array.length balls) (fun x -> x)) in
    let g = {
        balls=balls;
        active=active;
    } in
    g

let eq_ball b b' =
    false

let make_move b d =
    { ball=b; dir=d; }

let apply_move g move = failwith "TODO apply_move"

let moves g = failwith "TODO moves"

let get_balls g =
    g.active
    |> Sint.elements
    |> List.map (fun i -> g.balls.(i))

let is_ball g p = failwith "TODO is_ball"

let ball_of_position game p = failwith "TODO ball_of_position"

let position_of_ball b =
    b.pos
