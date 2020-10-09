type direction = Up | Right | Down | Left | Stay

(* I'm not a fan of the "if a ball touches another it can't be launched in that direction" rule.
 * I think it lacks coherency with the case where a ball hits two balls that touch each other.
 * I'll leave this boolean flag here, it may be turned on/off to select which rule to play by.
 *)
let allow_contact_launch = true

let pos_of_dir = function
    | Up -> Position.from_int 0 1
    | Down -> Position.from_int 0 (-1)
    | Left -> Position.from_int (-1) 0
    | Right -> Position.from_int 1 0
    | Stay -> failwith "Unreachable @pos_of_dir::Stay"

(** a single operation of changing a ball's position *)
type displacement = {
    id: int; (* ball that was displaced *)
    old_pos: Position.t;
    new_pos: Position.t option;
}

type ball = {
    id: int; (* unique identifier *)
    pos: Position.t;
}

type move = {
    ball: ball;
    dir: direction;
}

type game = {
    balls: (int, Position.t) Hashtbl.t; (* direct access id -> position *)
    grid: (Position.t, int) Hashtbl.t; (* direct access position -> id *)
    mutable hist: displacement list; (* history of all previous moves *)
    mutable fwd: displacement list; (* history of undone moves *)
    mutable added: ball list; (* balls to redraw *)
    mutable removed: Position.t list; (* positions to clear *)
}

let deep_copy g = {
    balls=Hashtbl.copy g.balls;
    grid=Hashtbl.copy g.grid;
    hist=g.hist;
    fwd=g.fwd;
    added=g.added;
    removed=g.removed;
}

let hist_push g disp =
    g.hist <- disp :: g.hist

let fwd_push g disp =
    g.fwd <- disp :: g.fwd

let make_disp id old_pos new_pos =
    { id=id; old_pos=old_pos; new_pos=new_pos; }

let hist_pop g =
    (* get displacements until either:
     * - hist is empty (gone back to initial state)
     * - next element has no new_pos
     * because a sequence of displacements *has* to end with a ball that went off the grid
     * => no new_pos means last element of previous move
     *)
    let rec aux b disps hist =
        match hist with
            | [] -> (disps, [])
            | disp::tl ->
                if b && disp.new_pos = None then (disps, disp::tl)
                else aux true (disp::disps) tl
    in
    let (disps, new_hist) = aux false [] g.hist in
    g.hist <- new_hist;
    disps

let fwd_pop g =
    (* get displacements until either:
     * - hist is empty (gone back to most advanced state)
     * - next element has no new_pos
     * because a sequence of displacements *has* to end with a ball that went off the grid
     * => no new_pos means last element of previous move
     *)
    let rec aux b disps fwd =
        match fwd with
            | [] -> (disps, [])
            | disp::tl ->
                if b && disp.new_pos = None then (disps, disp::tl)
                else aux true (disp::disps) tl
    in
    let (disps, new_fwd) = aux false [] g.fwd in
    g.fwd <- new_fwd;
    disps

let fwd_clear g =
    g.fwd <- []

let grid_width = 15
let grid_height = 15

let make_ball id p = { id=id; pos=p }

let ball_of_position game p =
    Hashtbl.find game.grid p
    |> fun i -> make_ball i p

let new_game bs =
    let balls = Hashtbl.create (grid_width + grid_height) in
    let grid = Hashtbl.create (grid_width + grid_height) in
    (* grid.width is a first guess at how many balls there will be.
     * ~one per column/line is a reasonable ballpark *)
    List.iter (fun b ->
        if not (Hashtbl.mem grid b.pos) then begin
            Hashtbl.add balls b.id b.pos;
            Hashtbl.add grid b.pos b.id
            end
            ) bs;
    { balls=balls; grid=grid; hist=[]; fwd=[]; added=bs; removed=[] }

let eq_ball b b' = b.id = b'.id

let make_move b d = { ball=b; dir=d; }

let is_ball g p = Hashtbl.mem g.grid p

let is_inside p =
    let x = Position.proj_x p
    and y = Position.proj_y p in
    0 <= x && x < grid_width && 0 <= y && y <= grid_height

(* each iteration of [apply_move] calculates the new position for a single ball
 * and recursively propagates the move to the 0 or 1 balls that were hit.
 * It stops when a ball goes off the edge.
 *)
let rec apply_move g move =
    (* Printf.printf "Apply move to ball %d\n" move.ball.id; *)
    let pstart = move.ball.pos in
    let p' = pos_of_dir move.dir in
    let p = ref pstart in
    let pnext = ref (Position.move !p p') in
    (* find another ball or the edge *)
    while (is_inside !p) && not (is_ball g !pnext) do
        p := !pnext;
        pnext := Position.move !p p';
    done;
    if is_inside !p then begin
        (* hit another ball, we have a few modifications to make *)
        let id_move = move.ball.id in
        (* update accessors *)
        Hashtbl.replace g.balls id_move !p;
        Hashtbl.remove g.grid pstart;
        Hashtbl.add g.grid !p id_move;
        (* add move to the history of g *)
        hist_push g (make_disp id_move pstart (Some !p));
        (* record changes for display *)
        g.added <- (make_ball id_move !p) :: g.added;
        g.removed <- pstart :: g.removed;
        (* propagate the move to the ball we hit *)
        apply_move g (make_move (ball_of_position g !pnext) move.dir)
    end else begin
        (* did not hit a ball, ball goes off the edge *)
        let id_remove = Hashtbl.find g.grid pstart in
        Hashtbl.remove g.grid pstart;
        Hashtbl.remove g.balls id_remove;
        (* add move to the history of g
         * this marks the end of a move (see more in pop_hist) *)
        hist_push g (make_disp id_remove pstart None);
        fwd_clear g;
        (* record changes for display *)
        g.removed <- pstart :: g.removed;
        g
    end

let undo_move g =
    let disps = hist_pop g in
    (* for each displacement... *)
    List.iter (fun disp ->
        fwd_push g disp;
        match disp.new_pos with
            | Some p -> (* ball stayed inside the grid, move it *)
                Hashtbl.remove g.grid p;
                Hashtbl.add g.grid disp.old_pos disp.id;
                Hashtbl.replace g.balls disp.id disp.old_pos;
                (* record changes *)
                g.added <- (make_ball disp.id disp.old_pos) :: g.added;
                g.removed <- p :: g.removed;
            | None -> (* ball went off the edge, put it back in *)
                Hashtbl.add g.grid disp.old_pos disp.id;
                Hashtbl.add g.balls disp.id disp.old_pos;
                (* record changes *)
                g.added <- (make_ball disp.id disp.old_pos) :: g.added;
        ) disps;
    g

let redo_move g =
    let disps = fwd_pop g in
    (* for each displacement... *)
    List.iter (fun disp ->
        hist_push g disp;
        match disp.new_pos with
            | Some p -> (* ball stays inside the grid, move it *)
                Hashtbl.remove g.grid disp.old_pos;
                Hashtbl.add g.grid p disp.id;
                Hashtbl.replace g.balls disp.id p;
                (* record changes *)
                g.added <- (make_ball disp.id p) :: g.added;
                g.removed <- disp.old_pos :: g.removed;
            | None -> (* ball goes off the edge *)
                Hashtbl.remove g.grid disp.old_pos;
                Hashtbl.remove g.balls disp.id;
                (* record changes *)
                g.removed <- disp.old_pos :: g.removed;
        ) disps;
    g

let moves_ball g b =
    (* for each possible move: *)
    [Up; Down; Right; Left]
    |> List.filter_map (fun m ->
        let pos = Hashtbl.find g.balls b.id in
        let p' = pos_of_dir m in
        let p = ref (Position.move pos p') in
        (* find another ball or the edge *)
        while (is_inside !p) && not (is_ball g !p) do
            p := Position.move !p p';
        done;
        (* it was a ball, the move is valid *)
        if allow_contact_launch && is_ball g !p then Some(make_move (make_ball b.id pos) m)
        else if is_ball g !p && !p <> (Position.move pos p') then Some(make_move (make_ball b.id pos) m)
        else None
    )

let moves g =
    g.balls
    (* equivalent to Hashtbl.keys, yields all balls still in game *)
    |> fun h -> Hashtbl.fold (fun k v acc -> { id=k; pos=v; } :: acc) h []
    |> List.map (moves_ball g)
    (* concatenate all. Notice x @ acc and not acc @ x for linear performance *)
    |> List.fold_left (fun acc x -> x @ acc) []

let get_balls g =
    g.balls
    (* equivalent to Hashtbl.items *)
    |> fun h -> Hashtbl.fold (fun k v acc -> (k, v) :: acc) h []
    |> List.map (fun (i, p) -> make_ball i p)

let position_of_ball b = b.pos

let direction_of_move mv = mv.dir

let has_undo g = g.hist != []

let has_redo g = g.fwd != []

let is_win g = (List.compare_length_with (get_balls g) 1) <= 0

let is_blocked g = (moves g) = []

let changed g =
    let add = g.added in
    let rem = g.removed in
    g.added <- [];
    g.removed <- [];
    (add, rem, g)

let is_valid_file str =
    let is_ok = function
        | 'a'..'z' | 'A'..'Z' | '0'..'9' | '-' | '_' | '.' -> true
        | _ -> false
    in
    let rec aux = function
        | [] -> true
        | hd::tl -> is_ok hd && aux tl
    in
    String.length str > 0 && aux (List.init (String.length str) (String.get str))

open Printf
let write_game name g =
    if is_valid_file name then (
        let name = ".data/" ^ name in
        let oc = open_out name in
        fprintf oc "Fling\nv0\nBEGIN\n";
        g.balls
        |> fun h -> Hashtbl.fold (fun id pos acc -> pos :: acc) h []
        |> List.iter (fun p -> fprintf oc "%d %d\n" (Position.proj_x p) (Position.proj_y p));
        fprintf oc "END\n";
        Ok ()
    ) else (
        Error "Invalid name (use only `azAZ09-_.`)"
    )

