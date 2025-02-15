module G = Graphics
module D = Draw
open Printf

let sleep n =
    let i = ref 0 in
    for j = 0 to n do
        i := Random.int 1024;
    done

type action =
    | Move of Rules.move
    | Ball of Rules.ball
    | Undo
    | Redo
    | Abort
    | Solve
    | Write

(* Controls *)
(* Do not edit the markers, as they are tags for chctrls *)
let k_mv_up = '.' (* KEY MOVE UP *)
let k_mv_dn = 'e' (* KEY MOVE DOWN *)
let k_mv_lt = 'o' (* KEY MOVE LEFT *)
let k_mv_rt = 'u' (* KEY MOVE RIGHT *)
let k_launch = 'i' (* KEY LAUNCH GAME *)
let k_mv_abrt = 'q' (* KEY ABORT MOVE *)
let k_quit_game = 'i' (* KEY QUIT GAME *)
let k_mv_undo = 'o' (* KEY MOVE UNDO *)
let k_mv_redo = 'u' (* KEY MOVE REDO *)
let k_fail = 'x' (* KEY FAIL *)
let k_solve = 's' (* KEY SOLVE *)
let k_write = 'w' (* KEY WRITE FILE *)

let void x = ()

let ball_highres = 10
let ball_lowres = 4

(* text data *)
let msg_init_game = sprintf "Create all balls. [start '%c'] [remove 'Del']" k_launch
let msg_select_ball = sprintf "Select a ball. [exit '%c']" k_quit_game
let msg_undo_move = sprintf " [undo '%c']" k_mv_undo
let msg_redo_move = sprintf " [redo '%c']" k_mv_redo
let msg_solve = sprintf " [solve '%c']" k_solve
let msg_write = sprintf " [write '%c']" k_write
let msg_forcequit = sprintf " [forcequit '%c']" k_fail
let msg_select_dir_before = "Select a direction ("
let msg_select_dir_after = sprintf "). [cancel '%c']" k_mv_abrt
let msg_no_moves = sprintf "This ball has no possible moves. [cancel '%c']" k_mv_abrt
let msg_lose = "There are no possible actions left. "
let msg_win = "There is only one ball left, YOU WIN ! "
let msg_exit = sprintf "[exit '%c']" k_quit_game
let msg_solved = "SOLVED ! Press any key to explore solution"
let msg_nosolve = "No solution"

(* balls is a reference to the initial configuration of balls *)
let balls = ref []

(* return the ball that the player wants to move *)
let rec get_ball game =
    (* extended to allow user to select either a ball or a key *)
    let status = G.wait_next_event [G.Button_down;G.Key_pressed] in
    if status.G.keypressed = true then (
        let k = Char.chr (Char.code status.G.key) in
        if k = k_fail then failwith "Program terminated on keypress"
        else match List.assoc_opt k [
            (k_quit_game, Abort);
            (k_mv_undo, Undo);
            (k_mv_redo, Redo);
            (k_write, Write);
            (k_solve, Solve);
        ] with
            | None -> get_ball game
            | Some action -> action
    ) else (
        (* check if a ball was selected *)
        let (x,y) = (status.G.mouse_x,status.G.mouse_y) in
        let p = D.position_of_coord x y in
        (* D.draw_game game; *)
        if Rules.is_ball game p then (
            let ball = Rules.ball_of_position game p in
            D.draw_ball ~select:true ball p; (* to show which ball has been selected *)
            Ball ball
        ) else get_ball game (* the player has selected an empty cell *)
    )

(* convert the key pressed into a char and call the continuation k on it *)
let get_key_pressed k =
    let status = G.wait_next_event [G.Key_pressed] in
    let key = Char.code status.G.key in
    k (Char.chr key)

(* Sometimes when we hold down a key the program becomes unresponsive
 * because it has to deal with all the queued keypresses.
 * This procedure solves this method by emptying the queue *)
let rec clear_event_queue () =
    let status = G.wait_next_event [G.Key_pressed; G.Poll] in (* Nonblocking, but does not dequeue *)
    if status.G.keypressed then
        let _ = G.wait_next_event [G.Key_pressed] in (* Dequeues, but blocking if no event is waiting *)
        clear_event_queue ()

(* return the direction choosen by the player *)
let rec get_ball_direction () =
    let dir_of_char c =
        Rules.(
            List.assoc_opt c [
                (k_mv_up, Up); (k_mv_dn, Down);
                (k_mv_rt, Right); (k_mv_lt, Left);
                (k_mv_abrt, Stay)
            ]
        )
    in
    get_key_pressed (fun c ->
        match dir_of_char c with
            | Some (x) -> x
            | None -> get_ball_direction () (* wrong key pressed by the player *)
        )

(* get the next move of the player *)
let get_next_move game =
    match get_ball game with
        | Ball p -> (
            let allowed = Rules.moves_ball game p in
                if allowed = [] then D.draw_string msg_no_moves
                else (
                    let dirs = allowed
                        |> List.map Rules.direction_of_move
                        |> List.map Rules.(function
                            | Up -> sprintf "[^] = '%c'" k_mv_up
                            | Down -> sprintf "[v] = '%c'" k_mv_dn
                            | Left -> sprintf "[<] = '%c'" k_mv_lt
                            | Right -> sprintf "[>] = '%c'" k_mv_rt
                            (* Stay is never valid *)
                            | Stay -> failwith "Unreachable @get_next_move::Ball::else::Stay"
                        )
                        |> String.concat " ; "
                    in D.draw_string (msg_select_dir_before ^ dirs ^ msg_select_dir_after)
                );
            let d = get_ball_direction () in Move (Rules.make_move p d)
        )
        (* only get_next_move (current function) can create Move *)
        | Move _ -> failwith "Unreachable @game::get_next_move::Move"
        | other -> other (* pass as is *)

(* add_balls creates new balls when the user clicks on the grid *)
let rec add_balls () =
    let status = G.wait_next_event [G.Button_down; G.Key_pressed] in
    if status.G.keypressed && Char.chr (Char.code status.G.key) = k_launch then (
        D.ready true; ()
    ) else if status.G.keypressed && Char.code status.G.key = 8 (* backspace *) then (
        (* remove the ball(s) at position pos *)
        let (x,y) = (status.G.mouse_x, status.G.mouse_y) in
        let pos = D.position_of_coord x y in
        D.hide_pos pos;
        balls := List.filter (fun (_, p) -> not (Position.eq pos p)) !balls;
        add_balls ()
    ) else (
        (* add a ball *)
        let (x,y) = (status.G.mouse_x, status.G.mouse_y) in
        let p = D.position_of_coord x y in
        let (x',y') = Position.coords p in
        (* balls can't be outside the grid *)
        if Rules.is_inside (Position.of_ints x' y') then (
            (* we don't have to check right now that the position is available because
            * game will manage duplicates *)
            let ball = Rules.new_ball () in
            D.draw_ball ball p;
            balls := (ball, p) :: !balls;
            add_balls ()
        ) else add_balls ()
    )

(* create_game allows the player to create its own game by putting balls over the grid *)
let create_game () =
    D.ready false;
    D.ball_quality ball_highres;
    D.draw_game (Rules.new_game !balls);
    D.draw_string msg_init_game;
    add_balls ()

(* A menu is a (string * (unit -> unit)) list.
 * The player chooses which function should be called *)
let rec menu = [("exit", leave);("play new", play);("load file", load_file)]
and menu_replay = [("exit", leave);("play new", play);("load file", load_file);("replay", replay)]
(* [play ()] allows the player to create a new game, and then try to solve it *)
and play () =
    balls := [];
    create_game ();
    loop (Rules.new_game !balls)

(* [loop game] loops on the game until the player chooses to exit
 * even if there are no possible moves left, allow undoing moves to explore *)
and loop game =
    D.draw_game game;
    let rec aux game =
        (* D.draw_game !game; *)
        (* display relevant help message *)
        let message = ref "" in
            if Rules.is_win game then message := msg_win ^ msg_exit
            else if Rules.is_blocked game then message := msg_lose ^ msg_exit
            else message := msg_select_ball;
            if Rules.has_undo game then message := !message ^ msg_undo_move;
            if Rules.has_redo game then message := !message ^ msg_redo_move;
            message := !message ^ msg_solve ^ msg_write ^ msg_forcequit;
            D.draw_string !message;
        (* get user action *)
        clear_event_queue ();
        let user = get_next_move game in
        match user with
            | Move user ->
                if List.mem user (Rules.moves game) then (
                    (* { b; Stay } is never allowed regardless of b,
                    * ensuring that Stay will never be converted into a Position.t *)
                    let (game, update) = Rules.apply_move game user in
                    List.iter (D.animate_ball 10) update;
                    aux game
                ) else (
                    let ball = Rules.ball_of_move user in
                    let p = Rules.position_of_ball game ball in
                    let update = (ball, p, p) in
                    D.animate_ball 1 update;
                    aux game
                )
            | Abort -> ()
            (* get_next_move will convert Ball -> Move, Ball will never pass through *)
            | Ball _ -> failwith "Unreachable @game::loop::while::Ball"
            | Undo ->
                let (game, update) = Rules.undo_move game in
                List.iter (D.animate_ball 5) update;
                aux game
            | Redo ->
                let (game, update) = Rules.redo_move game in
                List.iter (D.animate_ball 5) update;
                aux game
            | Solve ->
                solver game;
                aux game
            | Write ->
                write_file game;
                D.draw_game game;
                aux game
    in
    aux game;
    D.draw_game game;
    main menu_replay

(* [solver game] solves the game if it is possible *)
and solver game  =
    D.ball_quality ball_highres;
    D.draw_game game;
    let solver = Solver.solve game in
    let rec aux solver =
        if Solver.step solver = None && not (G.wait_next_event [G.Key_pressed; G.Poll]).keypressed then (
            (* nonblocking keyboard check *)
            D.draw_string (sprintf "Exploring %dth step. [cancel ' ']" (Solver.count solver));
            aux solver
        ) else ()
    in aux solver;
    if not (Solver.is_solved solver) then Solver.leave solver;
    let game = Solver.game solver in
    D.ball_quality ball_highres;
    D.draw_game game;
    if Solver.is_solved solver then D.draw_string msg_solved
    else D.draw_string msg_nosolve;
    get_key_pressed void

(* replay the previous game *)
and replay () =
    create_game ();
    loop (Rules.new_game !balls)
(* leave the application *)
and leave () =
    D.close_window ()
(* open previously saved file *)
and load_file () =
    D.ball_quality ball_highres;
    let name = get_filename () in
    if name <> "" then (
        match Rules.load_game name with
            | Ok pos ->
                D.ready false;
                D.draw_game (Rules.new_game []);
                (* draw balls from file *)
                balls := List.map (fun p -> (Rules.new_ball (), p)) pos;
                List.iter (fun (b, p) -> D.draw_ball b p) !balls;
                D.draw_string msg_init_game;
                (* allow user to add or remove balls *)
                create_game ();
                loop (Rules.new_game !balls)
            | Error msg ->
                G.clear_graph ();
                D.draw_string msg;
                get_key_pressed void;
                main menu
    ) else main menu

(* create new save file *)
and write_file g =
    let name = get_filename () in
    match Rules.write_game name g with
        | Ok () -> ()
        | Error msg -> (
            G.clear_graph ();
            D.draw_string msg;
            get_key_pressed void
            )

(* obtain filename from user *)
and get_filename () =
    (* remove last char *)
    let truncate str =
        if String.length str > 0 then
            String.sub str 0 (String.length str - 1)
        else str
    in
    (* add one more char *)
    let append str c =
        if String.length str < 20 then
            str ^ (String.make 1 c)
        else str
    in
    (* test if sub is a subsequence of src, also checks leading period.
     * This is our filter condition. *)
    let has_substr sub src =
        let str_get_opt str idx =
            if idx >= String.length str then None
            else Some str.[idx]
        in
        let rec aux i j =
            if i = String.length sub then true
            else if j = String.length src then false
            else if sub.[i] = src.[j] then aux (i+1) (j+1)
            else aux i (j+1)
        in
        if str_get_opt sub 0 <> Some '.' && str_get_opt src 0 = Some '.' then false
        else aux 0 0
    in
    let files = Array.to_list (Sys.readdir ".data") in
    let display = "" in (* string currently visible *)
    let compatible = List.filter (has_substr display) files in (* filenames compatible (in the sense of has_substr) with display *)
    let cycling = [] in (* cycle through possibilities on tab *)
    D.text_feedback "" compatible;
    let rec aux display compatible cycling =
        (* get input *)
        let status = G.wait_next_event [G.Key_pressed] in
        let key = status.G.key in
        let code = Char.code key in
        match code with
            | 13 (* enter *) -> display
            | 27 (* escape *) -> ""
            | 8 (* backspace *) ->
                let display = truncate display in
                let cycling = [] in
                let compatible = List.filter (has_substr display) files in
                D.text_feedback display compatible;
                aux display compatible cycling
            | 9 (* tab *) ->
                (* cycle through all compatible names *)
                let cycling = if cycling = [] then compatible else cycling in
                let (display, cycling) =
                    if cycling <> [] then (List.hd cycling, List.tl cycling)
                    else (display, cycling)
                in
                D.text_feedback display compatible;
                aux display compatible cycling
            | _ ->
                (* add one character + update compatible *)
                let display = append display key in
                let cycling = [] in
                let compatible = List.filter (has_substr display) files in
                D.text_feedback display compatible;
                aux display compatible cycling
    in
    aux display compatible cycling

(* get the choice of the player *)
and main l =
    let choice c =
        let i = (int_of_char c) - (int_of_char '0') in
        if 0 <= i && i < List.length l then
            snd (List.nth l i) ()
        else
            main l
    in
    Random.self_init ();
    D.init_window ();
    D.draw_menu l;
    get_key_pressed choice

let _ = main menu
