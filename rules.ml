type direction = Up | Right | Down | Left | Stay

let pos_of_dir = function
    | Up -> Position.from_int 0 1
    | Down -> Position.from_int 0 (-1)
    | Left -> Position.from_int (-1) 0
    | Right -> Position.from_int 1 0
    | Stay -> failwith "Stay cannot be made into a nonzero position"

type ball = {
    id: int;
    pos: Position.t;
}

type move = {
    ball: ball;
    dir: direction;
}

type game = {
    balls: (int, Position.t) Hashtbl.t; (* direct access id -> position *)
    grid: (Position.t, int) Hashtbl.t (* direct access position -> id *)
}

let deep_copy g =
    { balls=Hashtbl.copy g.balls; grid=Hashtbl.copy g.grid; }

let grid_width = 15
let grid_height = 15

let make_ball id p =
    { id=id; pos=p }

let ball_of_position game p =
    Hashtbl.find game.grid p
    |> fun i -> make_ball i p

let new_game bs =
    let balls = Hashtbl.create (grid_width + grid_height) in
    (* grid.width is a first guess at how many balls there will be.
     * ~one per column/line is a reasonable ballpark *)
    List.iter (fun b -> Hashtbl.add balls b.id b.pos) bs;
    let grid = Hashtbl.create (grid_width + grid_height) in
    List.iter (fun b -> Hashtbl.add grid b.pos b.id) bs;
    { balls=balls; grid=grid; }

let eq_ball b b' =
    b.id = b'.id

let make_move b d =
    { ball=b; dir=d; }

let is_ball g p =
    Hashtbl.mem g.grid p

let is_inside p =
    let x = Position.proj_x p
    and y = Position.proj_y p in
    0 <= x && x < grid_width && 0 <= y && y <= grid_height

let rec apply_move g move =
    let p' = pos_of_dir move.dir in
    let p = ref move.ball.pos in
    while (is_inside !p) && not (is_ball g (Position.move !p p')) do
        p := Position.move !p p';
    done;
    if is_inside !p then begin
        (* hit another ball, we have a few modifications to make *)
        let id_move = move.ball.id in
        Hashtbl.replace g.balls id_move !p;
        Hashtbl.remove g.grid move.ball.pos;
        Hashtbl.add g.grid !p id_move;
        (* and we have to propagate the move to the ball we hit *)
        apply_move g (make_move (ball_of_position g (Position.move !p p')) move.dir)
    end else begin
        (* did not hit a ball, ball goes off the edge *)
        let id_remove = Hashtbl.find g.grid move.ball.pos in
        Hashtbl.remove g.grid move.ball.pos;
        Hashtbl.remove g.balls id_remove;
        g
    end

let moves g =
    let mv = ref [] in
    let find_moves_ball id =
        List.iter (fun m ->
                let pos = Hashtbl.find g.balls id in
                let p' = pos_of_dir m in
                let p = ref (Position.move pos p') in
                while (is_inside !p) && not (is_ball g !p) do
                    p := Position.move !p p';
                done;
                if is_ball g !p then
                    mv := (make_move (make_ball id pos) m) :: !mv;
            ) [Up; Down; Right; Left]
    in
    g.balls
    |> fun h -> Hashtbl.fold (fun k v acc -> k :: acc) h []
    |> List.iter find_moves_ball;
    !mv

let get_balls g =
    g.balls
    |> fun h -> Hashtbl.fold (fun k v acc -> (k, v) :: acc) h []
    |> List.map (fun (i, p) -> make_ball i p)


let position_of_ball b =
    b.pos
