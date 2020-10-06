type direction = Up | Right | Down | Left

let pos_of_dir = function
    | Up -> Position.from_int 0 (-1)
    | Down -> Position.from_int 0 1
    | Left -> Position.from_int (-1) 0
    | Right -> Position.from_int 1 0

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
    balls: ball array; (* direct access id -> ball *)
    active: Sint.t; (* lists all balls currently in game *)
    grid: (Position.t, int) Hashtbl.t (* direct access position -> is_ball *)
}

let grid_width = 15
let grid_height = 15

let make_ball id p =
    { id=id; pos=p }

let new_game bs =
    (* use an array for better access *)
    let balls = Array.of_list bs in
    (* start with all balls active *)
    let active = Sint.of_list (List.init (Array.length balls) (fun x -> x)) in
    let grid = Hashtbl.create 10 in
    List.iter (fun b -> Hashtbl.add grid b.pos b.id) bs;
    let g = {
        balls=balls;
        active=active;
        grid=grid;
    } in
    g

let eq_ball b b' =
    b.id = b'.id

let make_move b d =
    { ball=b; dir=d; }

let apply_move g move = failwith "TODO apply_move"

let is_inside p =
    let x = Position.proj_x p
    and y = Position.proj_y p in
    0 <= x && x < grid_width && 0 <= y && y <= grid_height

let is_ball g p =
    Hashtbl.find_opt g.grid p != None

let moves g =
    let mv = ref [] in
    let find_moves_ball b =
        List.iter (fun m ->
                let p = ref b.pos in
                let p' = pos_of_dir m in
                while (is_inside !p) && not (is_ball g !p) do
                    p := Position.move !p p';
                done;
                if is_ball g !p then
                    mv := (make_move b m) :: !mv;
            ) [Up; Down; Right; Left]
    in
    g.active
    |> Sint.elements
    |> List.map (fun i -> g.balls.(i))
    |> List.iter find_moves_ball;
    !mv

let get_balls g =
    g.active
    |> Sint.elements
    |> List.map (fun i -> g.balls.(i))

let ball_of_position game p =
    Hashtbl.find game.grid p
    |> fun i -> game.balls.(i)

let position_of_ball b =
    b.pos
