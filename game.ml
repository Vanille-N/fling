module G = Graphics
module D = Draw

let rec sleep = function
    | 0 -> 0
    | 1 -> 1
    | n -> (sleep (n-1)) + (sleep (n-2))

type action =
    | Move of Rules.move
    | Ball of Rules.ball
    | Undo
    | Redo
    | Abort

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

let message_init_game = Printf.sprintf "Create all balls then press %c to start" k_launch
let message_select_ball = Printf.sprintf "Select a ball or exit with %c" k_quit_game
let message_undo_move = Printf.sprintf " or undo with %c" k_mv_undo
let message_redo_move = Printf.sprintf " or redo with %c" k_mv_redo
let message_select_dir_before = "Select a direction ("
let message_select_dir_after = Printf.sprintf ") or cancel with %c" k_mv_abrt
let message_no_moves = Printf.sprintf "This ball has no possible moves. Cancel with %c" k_mv_abrt
let message_lose = "There are no possible actions left. "
let message_win = "There is only one ball left, YOU WIN ! "
let message_exit = Printf.sprintf "Exit with %c" k_quit_game
let message_solved = "SOLVED ! Press any key to explore solution"
let message_nosolve = "No solution"

(* max width of the grid printed *)
let max_x = Rules.grid_width

(* max height of the grid printed *)
let max_y = Rules.grid_height

(* game is a reference to the initial game. *)
let game = ref (Rules.new_game [])

(* return the ball that the player wants to move *)
let rec get_ball game =
    (* extended to allow user to select either a ball or a key *)
    let status = G.wait_next_event [G.Button_down;G.Key_pressed] in
    if status.G.keypressed = true then begin
        if Char.chr (Char.code status.G.key) = k_quit_game then Abort
        else if Char.chr (Char.code status.G.key) = k_mv_undo then Undo
        else if Char.chr (Char.code status.G.key) = k_mv_redo then Redo
        else if Char.chr (Char.code status.G.key) = k_fail then failwith "Program terminated on keypress"
        else get_ball game (* not a valid key, keep waiting *)
    end else begin
        (* check if a ball was selected *)
        let (x,y) = (status.G.mouse_x,status.G.mouse_y) in
        let p = D.position_of_coord x y in
        D.draw_game max_x max_y game;
        if Rules.is_ball game p then
            begin
                let ball = Rules.ball_of_position game p in
                D.draw_ball ~select:true ball; (* to show which ball has been selected *)
                Ball ball
            end
        else
            get_ball game (* the player has selected an empty cell *)
    end

(* convert the key pressed into a char and call the continuation k on it *)
let get_key_pressed k =
    let status = G.wait_next_event [G.Key_pressed] in
    let key = Char.code status.G.key in
    k (Char.chr key)

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
                if allowed = [] then D.draw_string message_no_moves
                else (
                    let dirs = allowed
                        |> List.map Rules.direction_of_move
                        |> List.map Rules.(function
                            | Up -> Printf.sprintf "[^] = '%c'" k_mv_up
                            | Down -> Printf.sprintf "[v] = '%c'" k_mv_dn
                            | Left -> Printf.sprintf "[<] = '%c'" k_mv_lt
                            | Right -> Printf.sprintf "[>] = '%c'" k_mv_rt
                            | Stay -> failwith "Unreachable @get_next_move::Ball::else::Stay" (* Stay is never valid *)
                        )
                        |> String.concat " ; "
                    in D.draw_string (message_select_dir_before ^ dirs ^ message_select_dir_after)
                    );
            let d = get_ball_direction () in Move (Rules.make_move p d)
            )
        | Move _ -> failwith "Unreachable @get_next_move::Move" (* only get_next_move can create Move *)
        | other -> other


(* create_game allows the player to create its own game by putting balls over the grid *)
let create_game () =
    D.ready false;
    D.draw_game max_x max_y (Rules.new_game []);
    D.draw_string message_init_game;
    let ball_count = ref 0 in
    let rec add_balls l =
        let status = G.wait_next_event [G.Button_down;G.Key_pressed] in
        if status.G.keypressed = true && Char.chr (Char.code status.G.key) = k_launch then
            begin Draw.ready true; l end
        else
            (* add a ball *)
            let (x,y) = (status.G.mouse_x, status.G.mouse_y) in
            let p = D.position_of_coord x y in
            let (x',y') = Position.proj_x p, Position.proj_y p in
            (* balls can not be outside the grid *)
            if 0 <= x' && x' < max_x && 0 <= y' && y' < max_y then
                (* we don't have to check right now that the position is available because
                 * game will manage it *)
                let ball = Rules.make_ball !ball_count p in
                incr ball_count;
                D.draw_ball ball;
                add_balls (ball::l)
            else
                add_balls l
    in
    let balls = add_balls [] in
    Rules.new_game balls

(* A menu is a (string * (unit -> unit)) list.
 * The player chooses which function should be called *)
let rec menu = [("solve new", solve);("play new", play);("exit", leave)]
and menu_replay = [("solve new", solve);("resolve", resolve);
                   ("play new", play); ("replay", replay); ("exit", leave)]
(* [play ()] allows the player to create a new game, and then try to solve it *)
and play () =
    game := create_game ();
    loop (Rules.deep_copy !game)

(* [solve ()] allows the player to create a new game and then see if the game can be solved *)
and solve () =
    game := create_game ();
    solver (Rules.deep_copy !game)

(* [loop game] loops on the game until the player chooses to exit
 * even if there are no possible moves left, allow undoing moves to explore *)
and loop game =
    let game = ref game in
    let stay = ref true in (* should we keep looping ? *)
    D.draw_game max_x max_y !game;
    while !stay do
        let (add, rem, g) = Rules.changed !game in
        game := g;
        D.redraw_game add rem;
        (* display relevant help message *)
        let message = ref "" in
            if Rules.is_win !game then message := message_win ^ message_exit
            else if Rules.is_blocked !game then message := message_lose ^ message_exit
            else message := message_select_ball;
            if Rules.has_undo !game then message := !message ^ message_undo_move;
            if Rules.has_redo !game then message := !message ^ message_redo_move;
            D.draw_string !message;
        (* get user action *)
        let user = get_next_move !game in
        match user with
            | Move user ->
                if List.mem user (Rules.moves !game) then (
                    (* { b; Stay } is never allowed regardless of b,
                    * ensuring that Stay will never be converted into a Position.t *)
                    game := Rules.apply_move !game user;
                ) else D.draw_game max_x max_y !game
            | Abort -> stay := false;
            | Ball _ -> failwith "Unreachable @loop::while::Ball" (* get_next_move will convert Ball -> Move *)
            | Undo -> game := Rules.undo_move !game
            | Redo -> game := Rules.redo_move !game
    done;
    D.draw_game max_x max_y !game;
    main menu_replay

(* [solver game] solves the game if it is possible *)
and solver game  =
    D.draw_game max_x max_y game;
    let solver = Solver.solve game in
    while Solver.step solver = None do
        let _ = sleep 1 in
        let (add, rem, _) = Rules.changed (Solver.game solver) in
        D.redraw_game add rem;
        D.draw_string (Printf.sprintf "Exploring %dth step" (Solver.count solver))
    done;
    let game = Solver.game solver in
    D.draw_game max_x max_y game;
    if Solver.step solver = Some true then D.draw_string message_solved
    else D.draw_string message_nosolve;
    get_key_pressed (fun x -> ());
    loop game

(* replay the previous game *)
and replay () =
    loop (Rules.deep_copy !game)
(* resolve the previous game *)
and resolve () =
    solver (Rules.deep_copy !game)
(* leave the application *)
and leave () =
    D.close_window()

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
