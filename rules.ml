type direction = Up | Right | Down | Left | Stay

(* I'm not a fan of the "if a ball touches another it can't be launched in that direction" rule.
 * I think it lacks coherency with the case where a ball hits two balls that touch each other.
 * I'll leave this boolean flag here, it may be turned on/off to select which rule to play by.
 *)
let allow_contact_launch = true

let pos_of_dir = function
    | Up -> Position.of_int 0 1
    | Down -> Position.of_int 0 (-1)
    | Left -> Position.of_int (-1) 0
    | Right -> Position.of_int 1 0
    | Stay -> failwith "Unreachable @pos_of_dir::Stay"

(** a single operation of changing a ball's position *)
type displacement = {
    id: int; (* ball that was displaced *)
    old_pos: Position.t;
    new_pos: Position.t;
}

type ball = int (* unique identifier *)

type move = {
    ball: ball;
    dir: direction;
}

type game = {
    balls: (int, Position.t) Hashtbl.t; (* direct access id -> position *)
    grid: (Position.t, int) Hashtbl.t; (* direct access position -> id *)
    mutable hist: displacement list list; (* history of all previous moves *)
    mutable fwd: displacement list list; (* history of undone moves *)
}

let deep_copy g = {
    balls = Hashtbl.copy g.balls;
    grid = Hashtbl.copy g.grid;
    hist = g.hist;
    fwd = g.fwd;
}

let hist_push g disp =
    g.hist <- disp :: g.hist

let fwd_push g disp =
    g.fwd <- disp :: g.fwd

let make_disp id old_pos new_pos =
    { id = id; old_pos = old_pos; new_pos = new_pos; }

let max_x = 15
let max_y = 15

let make_ball id = id

let ball_of_position game p =
    Hashtbl.find game.grid p

let position_of_ball game b =
    Hashtbl.find game.balls b

let clear_fwd game =
    game.fwd <- []

let new_game bs =
    let balls = Hashtbl.create (max_x + max_y) in
    let grid = Hashtbl.create (max_x + max_y) in
    (* grid.width is a first guess at how many balls there will be.
     * ~one per column/line is a reasonable ballpark *)
    List.iter (fun (id, pos) ->
        if not (Hashtbl.mem grid pos) then begin
            Hashtbl.add balls id pos;
            Hashtbl.add grid pos id
            end
            ) bs;
    { balls = balls; grid = grid; hist = []; fwd = []; }

let eq_ball b b' =
    b = b'

let make_move b d = { ball = b; dir = d; }

let is_ball g p = Hashtbl.mem g.grid p

let is_inside p =
    let x = Position.proj_x p
    and y = Position.proj_y p in
    0 <= x && x < max_x && 0 <= y && y <= max_y

(* each iteration of [apply_move] calculates the new position for a single ball
 * and recursively propagates the move to the 0 or 1 balls that were hit.
 * It stops when a ball goes off the edge.
 *)
let apply_move g move =
    let moved = ref [] in
    let rec aux g ball =
        (* Printf.printf "Apply move to ball %d\n" move.ball.id; *)
        let pstart = position_of_ball g ball in
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
            let id_move = ball in
            (* update accessors *)
            Hashtbl.replace g.balls id_move !p;
            Hashtbl.remove g.grid pstart;
            Hashtbl.add g.grid !p id_move;
            (* add move to the history of g *)
            moved := (make_disp id_move pstart !p) :: !moved;
            (* propagate the move to the ball we hit *)
            aux g (ball_of_position g !pnext)
        end else begin
            (* did not hit a ball, ball goes off the edge *)
            let id_remove = Hashtbl.find g.grid pstart in
            Hashtbl.remove g.grid pstart;
            Hashtbl.remove g.balls id_remove;
            (* add move to the history of g
             * this marks the end of a move (see more in pop_hist) *)
            moved := (make_disp id_remove pstart !p) :: !moved;
            clear_fwd g;
            g
        end
    in
    let g = aux g move.ball in
    g.hist <- (List.rev !moved) :: g.hist;
    g

let undo_move g =
    let disps = (match g.hist with [] -> [] | hd::tl -> (g.hist <- tl; hd)) in
    List.iter (fun (disp:displacement) ->
        Printf.printf "[%d %s->%s]" disp.id (Position.to_string disp.old_pos) (Position.to_string disp.new_pos);
        ) disps;
    Printf.printf "\n";
    flush stdout;
    (* for each displacement... *)
    List.iter (fun disp ->
        match disp.new_pos with
            | p when is_inside p -> (* ball stayed inside the grid, move it *)
                Hashtbl.remove g.grid p;
                Hashtbl.add g.grid disp.old_pos disp.id;
                Hashtbl.replace g.balls disp.id disp.old_pos;
            | p -> (* ball went off the edge, put it back in *)
                Hashtbl.add g.grid disp.old_pos disp.id;
                Hashtbl.add g.balls disp.id disp.old_pos;
        ) disps;
    if disps <> [] then g.fwd <- disps :: g.fwd;
    g

let redo_move g =
    let disps = (match g.fwd with [] -> [] | hd::tl -> (g.fwd <- tl; hd)) in
    (* for each displacement... *)
    List.iter (fun disp ->
        match disp.new_pos with
            | p when is_inside p -> (* ball stays inside the grid, move it *)
                Hashtbl.remove g.grid disp.old_pos;
                Hashtbl.add g.grid p disp.id;
                Hashtbl.replace g.balls disp.id p;
            | p -> (* ball goes off the edge *)
                Hashtbl.remove g.grid disp.old_pos;
                Hashtbl.remove g.balls disp.id;
        ) disps;
    if disps <> [] then g.hist <- disps :: g.hist;
    g

let moves_ball g (b:ball) =
    (* for each possible move: *)
    [Up; Down; Right; Left]
    |> List.filter_map (fun m ->
        let pos = Hashtbl.find g.balls b in
        let p' = pos_of_dir m in
        let p = ref (Position.move pos p') in
        (* find another ball or the edge *)
        while (is_inside !p) && not (is_ball g !p) do
            p := Position.move !p p';
        done;
        (* it was a ball, the move is valid *)
        if allow_contact_launch && is_ball g !p then Some (make_move b m)
        else if is_ball g !p && !p <> (Position.move pos p') then Some (make_move b m)
        else None
    )

let moves g =
    g.balls
    (* equivalent to Hashtbl.keys, yields all balls still in game *)
    |> fun h -> Hashtbl.fold (fun k v acc -> k :: acc) h []
    |> List.map (moves_ball g)
    (* concatenate all. Notice x @ acc and not acc @ x for linear performance *)
    |> List.fold_left (fun acc x -> x @ acc) []

let get_balls g =
    g.balls
    (* equivalent to Hashtbl.items *)
    |> fun h -> Hashtbl.fold (fun k v acc -> k :: acc) h []

let direction_of_move mv = mv.dir

let has_undo g = g.hist != []

let has_redo g = g.fwd != []

let is_win g = (List.compare_length_with (get_balls g) 1) <= 0

let is_blocked g = (moves g) = []

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
        close_out oc;
        Ok ()
    ) else (
        Error "Invalid name (use only `azAZ09-_.`)"
    )

let load_game name =
    let name = ".data/" ^ name in
    if Sys.file_exists name then (
        let pos = ref [] in
        let ic = open_in name in
        let rec read b =
            try
                let line = input_line ic in
                if line = "BEGIN" then read true
                else if line = "END" then Ok ()
                else (
                    if b then (
                        let sp = String.split_on_char ' ' line in
                        let x = sp |> List.hd |> int_of_string in
                        let y = sp |> List.tl |> List.hd |> int_of_string in
                        pos := (Position.of_int x y) :: !pos;
                    );
                    read b
                )
            with e -> Error "Malformed file"
        in
        let res = read false in
        close_in ic;
        match res with
            | Ok () -> Ok !pos
            | Error msg -> Error msg
    ) else Error "File does not exist"
