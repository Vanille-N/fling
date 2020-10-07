module G = Graphics
module D = Draw


(* Controls *)
(* Do not edit the markers, as they are tags for chctrls *)
let k_mv_up = '.' (* KEY MOVE UP *)
let k_mv_dn = 'e' (* KEY MOVE DOWN *)
let k_mv_lt = 'o' (* KEY MOVE LEFT *)
let k_mv_rt = 'u' (* KEY MOVE RIGHT *)
let k_launch = 'i' (* KEY LAUNCH GAME *)
let k_mv_abrt = 'q' (* KEY ABORT MOVE *)

(* max width of the grid printed *)
let max_x = Rules.grid_width

(* max height of the grid printed *)
let max_y = Rules.grid_height

(* game is a reference to the initial game. *)
let game = ref (Rules.new_game [])

(* return the ball that the player wants to move *)
let rec get_ball game =
  let status = G.wait_next_event [G.Button_down] in
  let (x,y) = (status.G.mouse_x,status.G.mouse_y) in
  let p = D.position_of_coord x y in
  if Rules.is_ball game p then
    begin
      let ball = Rules.ball_of_position game p in
      D.draw_ball ~select:true ball; (* to show which ball has been selected *)
      ball
    end
  else
    get_ball game (* the player has selected an empty cell *)

(* convert the key pressed into a char and call the continuation k on it *)
let get_key_pressed k =
  let status = G.wait_next_event [G.Key_pressed] in
  let key = Char.code status.G.key in
  k (Char.chr key)

(* return the direction choosen by the player *)
let rec get_ball_direction () =
  let dir_of_char c =
    Rules.(
      match c with
      | c when c=k_mv_up -> Some Up
      | c when c=k_mv_dn -> Some Down
      | c when c=k_mv_rt -> Some Right
      | c when c=k_mv_lt -> Some Left
      | c when c=k_mv_abrt -> Some Stay
      | _ -> None
    )
  in
  get_key_pressed (fun c -> match dir_of_char c with
      | Some (x) -> x
      | None -> get_ball_direction () (* wrong key pressed by the player *)
    )

(* get the next move of the player *)
let get_next_move game =
  let p = get_ball game in
  let d = get_ball_direction () in
  Rules.make_move p d


(* create_game allows the player to create its own game by putting balls over the grid *)
let create_game () =
  D.ready false;
  D.draw_game max_x max_y (Rules.new_game []);
  let ball_count = ref 0 in
  let rec add_balls l =
    let status = G.wait_next_event [G.Button_down;G.Key_pressed] in
    if status.G.keypressed = true && Char.chr (Char.code status.G.key) = k_launch then
      begin Draw.ready true; l end
    else
      let (x,y) = (status.G.mouse_x, status.G.mouse_y) in
      let p = D.position_of_coord x y in
      let (x',y') = Position.proj_x p, Position.proj_y p in
      (* balls can not be outside the grid *)
      if 0 <= x' && x' < max_x && 0 <= y' && y' < max_y then
        let ball = Rules.make_ball !ball_count p in
        incr ball_count;
        D.draw_ball ball;
        add_balls (ball::l)
      else
        add_balls l
  in
  let balls = add_balls [] in
  Rules.new_game balls

(* A menu is a pair of string * f where f is a function of type unit -> unit.
   If the player choose on the menu which function should be called *)
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

(* [loop game] loops on the game while there are still moves possible for the player *)
and loop game =
  let game = ref game in
  let allowed = ref (Rules.moves !game) in
  while !allowed <> [] do
    D.draw_game max_x max_y !game;
    let user = get_next_move !game in
    if List.mem user !allowed then begin
        (* { b; Stay } is never allowed regardless of b,
         * ensuring that Stay will never be converted into a Position.t *)
        game := Rules.apply_move !game user;
        allowed := Rules.moves !game;
    end
  done;
  D.draw_game max_x max_y !game;
  get_key_pressed (fun c -> ());
  main menu_replay

(* [solver game] solves the game if it is possible *)
and solver game  =
  D.draw_game max_x max_y game;
  let moves = Solver.solve game in
  match moves with
  | None -> D.draw_string "No solution!"; get_key_pressed (fun c -> main menu)
  | Some moves ->
    let g = List.fold_left (fun g m -> D.draw_game max_x max_y g ;
                             D.draw_string "Solved!";
                             get_key_pressed (fun c -> ());
                             Rules.apply_move g m) game moves
    in
    D.draw_game max_x max_y g;
    get_key_pressed (fun c -> main (("resolve", resolve)::menu))

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
  Random.self_init();
  D.init_window();
  D.draw_menu l;
  get_key_pressed choice

let _ = main menu
