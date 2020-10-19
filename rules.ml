type direction = Up | Right | Down | Left | Stay

(* I'm not a fan of the "if a ball touches another it can't be launched in that direction" rule.
 * I think it lacks coherency with the case where a ball hits two balls that touch each other.
 * I'll leave this boolean flag here, it may be turned on/off to select which rule to play by.
 *)
let allow_contact_launch = false

let pos_of_dir = function
    | Up -> Position.of_ints 0 1
    | Down -> Position.of_ints 0 (-1)
    | Left -> Position.of_ints (-1) 0
    | Right -> Position.of_ints 1 0
    | Stay -> failwith "Unreachable @rules::pos_of_dir::Stay"

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

let make_disp id old_pos new_pos =
    { id = id; old_pos = old_pos; new_pos = new_pos; }

let max_x = 15
let max_y = 15

let new_ball =
    (* ball_count is closured to ensure no two balls have the same identifier *)
    let ball_count = ref 0 in
    (fun () ->
        if !ball_count > 50000 then ball_count := 0;
        incr ball_count;
        !ball_count
    )

let ball_of_position game p =
    Hashtbl.find game.grid p

let position_of_ball game b =
    Hashtbl.find game.balls b

let ball_of_move mv = mv.ball

let clear_redo game =
    game.fwd <- []

let new_game bs =
    let balls = Hashtbl.create (max_x + max_y) in
    let grid = Hashtbl.create (max_x + max_y) in
    (* height+width is a first guess at how many balls there will be.
     * ~one per column/line is a reasonable ballpark *)
    List.iter (fun (id, pos) ->
        if not (Hashtbl.mem grid pos) then (
            Hashtbl.add balls id pos;
            Hashtbl.add grid pos id
        )
    ) bs;
    { balls = balls; grid = grid; hist = []; fwd = []; }

let eq_ball b b' =
    b = b'

let make_move b d = { ball = b; dir = d; }

let is_ball g p = Hashtbl.mem g.grid p

let is_inside p =
    let (x, y) = Position.coords p in
    0 <= x && x < max_x && 0 <= y && y < max_y

let closest_inside p =
    let (x, y) = Position.coords p in
    let x = min (max_x - 1) (max 0 x)
    and y = min (max_y - 1) (max 0 y) in
    Position.of_ints x y

let unpack (mv:displacement) =
    (mv.id, mv.old_pos, mv.new_pos)

(* change a displacement into its opposite *)
let disp_rev (id, old_pos, new_pos) = (id, new_pos, old_pos)

(* each iteration of [aux] inside [apply_move] calculates the new position
 * for a single ball and recursively propagates the move to the 0 or 1
 * balls that were hit.
 * It stops when a ball goes off the edge.
 *)
let apply_move g move =
    let rec aux g ball moved =
        (* Printf.printf "Apply move to ball %d\n" move.ball.id; *)
        let start = position_of_ball g ball in
        let move = pos_of_dir move.dir in
        let curr = start in
        let next = (Position.move curr move) in
        let rec find_next curr next =
            if is_inside curr && not (is_ball g next) then
                let curr = next in
                let next = Position.move curr move in
                find_next curr next
            else (curr, next)
        in
        let (curr, next) = find_next curr next in
        if is_inside curr then begin
            (* hit another ball, we have a few modifications to make *)
            let id_move = ball in
            (* update accessors *)
            Hashtbl.replace g.balls id_move curr;
            Hashtbl.remove g.grid start;
            Hashtbl.add g.grid curr id_move;
            (* propagate the move to the ball we hit *)
            aux g (ball_of_position g next) ((make_disp id_move start curr)::moved)
        end else begin
            (* did not hit a ball, ball goes off the edge *)
            let id_remove = Hashtbl.find g.grid start in
            Hashtbl.remove g.grid start;
            Hashtbl.remove g.balls id_remove;
            clear_redo g;
            (g, (make_disp id_remove start curr)::moved)
        end
    in
    let (g, moved) = aux g move.ball [] in
    let moved = List.rev moved in
    g.hist <- moved :: g.hist;
    (g, List.map unpack moved)

let undo_move g =
    let disps = (match g.hist with [] -> [] | hd::tl -> (g.hist <- tl; hd)) in
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
    (g, List.map (fun mv -> disp_rev (unpack mv)) disps |> List.rev)

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
    (g, List.map unpack disps)

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
    (* concatenate all. Notice x @ acc and not acc @ x for linear rather that quadratic performance *)
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

(* checks filename against ^[a-zA-Z0-9_\.\-]+$ *)
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

let write_game name g =
    let encode_v0 g =
        (* as a list of coordinates *)
        let data = g.balls
            |> fun h -> Hashtbl.fold (fun k v acc -> v::acc) h []
            |> List.map Position.coords
            |> List.map (fun (x, y) -> Printf.sprintf "%d %d" x y)
            |> String.concat "\n"
        in "BEGIN\nv0\n" ^ data ^ "\nEND"
    in
    let encode_v1 g =
        (* as a matrix *)
        let range n =
            let rec aux lst = function
                | 0 -> 0::lst
                | n -> aux (n::lst) (n-1)
            in aux [] (n-1)
        in
        let data = range max_y
            |> List.map (fun y ->
                range max_x
                |> List.map (fun x -> Position.of_ints x y)
                |> List.map (is_ball g)
                |> List.map (fun b -> if b then '*' else '.')
                |> List.map (String.make 1)
                |> String.concat ""
            )
            |> String.concat "\n"
        in "BEGIN\nv1\n" ^ data ^ "\nEND"
    in
    let argmin f lst =
        let rec aux m x = function
            | [] -> x
            | hd::tl when f hd < m -> aux (f hd) hd tl
            | hd::tl -> aux m x tl
        in
        let x = List.hd lst in
        aux (f x) x (List.tl lst)
    in
    if is_valid_file name then (
        let name = ".data/" ^ name in
        let oc = open_out name in
        let v0 = encode_v0 g in
        let v1 = encode_v1 g in

        (* the following requires `Unix`.
         * If not available, comment this and uncomment the one below *)
        (* BEGIN REQUIRES UNIX *)
        let header = Unix.(
            let t = gmtime (time ()) in
            let year = t.tm_year + 1900
            and month = t.tm_mon
            and day = t.tm_mday
            and hour = t.tm_hour
            and min = t.tm_min
            and sec = t.tm_sec in
            Printf.sprintf "Fling -- save file
Neven Villani
%d/%d/%d %d:%d:%d" year month day hour min sec
        ) in
        (* END REQUIRES UNIX *)
        (* BEGIN FALLBACK *)
        (* let header = "Fling -- save file
Neven Villani" in *)
        (* END FALLBACK *)
        (* choose most efficent encoding *)
        Printf.fprintf oc "%s\n%s" header (argmin (fun s -> List.length (String.split_on_char '\n' s)) [v0; v1]);
        close_out oc;
        Ok ()
    ) else (
        Error "Invalid name (use only `azAZ09-_.`)"
    )

let load_game name =
    let name = ".data/" ^ name in
    if Sys.file_exists name then (
        let ic = open_in name in
        let rec read_header () =
            (* ignore comments until "BEGIN" *)
            try
                let line = input_line ic in
                if line = "BEGIN" then read_encoding ()
                else read_header ()
            with e -> Error "BEGIN not found"
        and read_encoding () =
            (* dispatch to proper decoding function *)
            try
                let line = input_line ic in
                if line = "v0" then read_v0 []
                else if line = "v1" then read_v1 0 []
                else Error "Not a valid encoding"
            with e -> Error "No encoding specified"
        and read_v0 pos =
            (* decode list of positions *)
            try
                let line = input_line ic in
                if line = "END" then (close_in ic; Ok pos)
                else (
                    let sp = String.split_on_char ' ' line in
                    let x = sp |> List.hd |> int_of_string in
                    let y = sp |> List.tl |> List.hd |> int_of_string in
                    read_v0 ((Position.of_ints x y)::pos)
                )
            with e -> Error "Malformed file"
        and read_v1 y pos =
            (* decode matrix *)
            try
                let line = input_line ic in
                if line = "END" then (close_in ic; Ok (List.concat pos))
                else (
                    let chars = List.init (String.length line) (String.get line) in
                    let p = chars
                        |> List.mapi (fun x c -> (x, c))
                        |> List.filter_map (fun (x, c) -> if c = '*' then Some x else None)
                        |> List.map (fun x -> Position.of_ints x y)
                    in read_v1 (y+1) (p::pos)
                )
            with e -> Error "Malformed file"
        in
        read_header ()
    ) else Error "File does not exist"
