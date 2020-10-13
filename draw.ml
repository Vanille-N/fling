module G = Graphics

let width = 700
let height = 700
let line_height = 25
let padding_left = 50
let padding_right = 50
let padding_up = 40
let padding_down = 50
let margin = 8
let cell_size = ref 0
let colors_generated = ref false
let colors = ref []
let ball_res = ref 1
let ball_quality n = ball_res := n
let max_x = 15
let max_y = 15

(* some colors *)
let red = G.rgb 200 0 0
let gray = G.rgb 128 128 128
let blue = G.rgb 0 100 200

let sleep n =
    let i = ref 0 in
    for j = 0 to n do
        i := Random.int 1024;
    done

let rgb_of_color c =
    let r = c / (256 * 256) in
    let g = (c / 256) mod 256 in
    let b = c mod 256 in
    (r, g, b)

let generate_new_color color =
    let mix i i' = (i + i') / 2 in
    let darken i = i * 2 / 3 in
    let red = Random.int 256 in
    let green = Random.int 256 in
    let blue = Random.int 256 in
    let (old_red, old_green, old_blue) = rgb_of_color color in
    G.rgb (darken (mix red old_red)) (darken (mix green old_green)) (darken (mix blue old_blue))

let init_window () =
    G.open_graph "";
    G.set_window_title "Fling";
    G.resize_window width height;
    G.clear_graph()

let close_window () =
    G.close_graph()

let draw_grid () =
    G.set_color G.black;
    let cell_width = (width - padding_left - padding_right) / Rules.max_x in
    let cell_height = (height - padding_up - padding_down) / Rules.max_y in
    cell_size := min cell_width cell_height;
    let start_x, start_y = padding_left, padding_down in
    let end_x, end_y = start_x + Rules.max_x * !cell_size, start_y + Rules.max_y * !cell_size in
    G.moveto start_x start_y;
    for i = 0 to Rules.max_x do
        G.lineto (G.current_x ()) end_y;
        G.moveto ((G.current_x ()) + !cell_size) start_y
    done;
    G.moveto padding_left padding_down;
    for i = 0 to Rules.max_y do
        G.lineto end_x (G.current_y ());
        G.moveto start_x ((G.current_y ()) + !cell_size)
    done

(* make balls prettier by adding a gradient *)
let pretty_ball x y color radius resolution =
    let resolution = max 1 resolution in
    (* color transformation to apply *)
    let profile i c =
        (256 * i / 2 + c * resolution - c * i / 2) / resolution
    in
    (* apply to all rgb components *)
    let lighter i =
        let (r, g, b) = rgb_of_color color in
        G.rgb (profile i r) (profile i g) (profile i b)
    in
    (* radius shrinks *)
    let radius_var i = (resolution - i) * radius / resolution in
    for i = 0 to pred resolution do
        G.set_color (lighter i);
        let r = radius_var i in
        G.fill_circle (x + (radius - r) / 4) (y + (radius - r) / 4) r
    done

let draw_ball ?select:(select=false) ball p =
    let size = !cell_size in
    let x = padding_left + Position.proj_x p * size + (size / 2) in
    let y = padding_left + Position.proj_y p * size + (size / 2) in
    let radius = (size - margin) / 2 in
    let color = (
        if select then
            red
        else if !colors_generated then  begin
            let color = fst (List.find (fun cb -> Rules.eq_ball (snd cb) ball) !colors) in
            color
        end else
            let color = generate_new_color G.white in
            colors := (color,ball)::!colors;
            color
    ) in
    if select then begin
        G.set_color red;
        (* G.draw_circle x y radius; *)
        G.draw_circle x y (radius+1);
        G.draw_circle x y (radius+2)
    end else
        pretty_ball x y color radius !ball_res

let hide x y =
    let size = !cell_size in
    let radius = (size - margin) / 2  + 4 in
    G.set_color G.white;
    G.fill_circle x y radius

let coord_of_position p = (
    let size = !cell_size in
    padding_left + Position.proj_x p * size + (size / 2),
    padding_left + Position.proj_y p * size + (size / 2)
    )

let position_of_coord x y =
    let size = !cell_size in
    let x', y' = x - padding_left, y - padding_down in
    Position.of_ints (x'/size) (y'/size)

let animate_ball speed (ball, old_pos, new_pos) =
    let size = !cell_size in
    let (old_x, old_y) = coord_of_position old_pos in
    let (new_x, new_y) = coord_of_position new_pos in
    let radius = (size - margin) / 2 in
    let color = fst (List.find (fun cb -> Rules.eq_ball (snd cb) ball) !colors) in
    let amount = (abs (old_x - new_x) + abs (old_y - new_y)) * speed in
    hide old_x old_y;
    for i = 1 to amount do
        let x = (i * new_x + (amount-i) * old_x) / amount in
        let y = (i * new_y + (amount-i) * old_y) / amount in
        let p = Rules.closest_inside (position_of_coord x y) in
        let (xc, yc) = coord_of_position p in
        hide x y;
        G.set_color G.black;
        G.moveto (xc - size/2) (yc - size/2);
        G.lineto (xc - size/2) (yc + size/2);
        G.lineto (xc + size/2) (yc + size/2);
        G.lineto (xc + size/2) (yc - size/2);
        G.lineto (xc - size/2) (yc - size/2);
        pretty_ball x y color radius !ball_res;
        sleep 4000;
    done;
    if Rules.is_inside new_pos then pretty_ball new_x new_y color radius !ball_res
    else hide new_x new_y

(* hide text zone *)
let clear_string () =
    G.set_color G.white;
    G.fill_rect 0 (height-10) width (height)

let draw_string s =
    clear_string ();
    G.moveto (width/10) (height-5);
    G.set_color red;
    G.draw_string s

let draw_game game =
    G.clear_graph ();
    draw_grid ();
    List.iter (fun b ->
        draw_ball b (Rules.position_of_ball game b)
        ) (Rules.get_balls game)

let draw_menu l =
    G.clear_graph ();
    G.set_color G.black;
    let (x,y) = (width/2, height/2) in
    G.moveto x y;
    ignore @@ List.fold_left (
        fun (i,y) (name,_) ->
            G.draw_string (Printf.sprintf "%d : %s" i name);
            let y' = y - line_height in
            G.moveto x y';
            (i+1,y')
        ) (0,y) l

let ready b = colors_generated := b

let text_feedback txt info =
    G.clear_graph ();
    let (x, y) = (width/3, ref (3*height/4)) in
    G.moveto x !y;
    if txt <> "" then (
        G.set_color red;
        G.draw_string txt
    ) else (
        G.set_color gray;
        G.draw_string "Enter text"
    );
    y := !y - 6;
    G.moveto (x-10) !y;
    G.set_color G.black;
    G.lineto (2*width/3) !y;
    if info <> [] then (
        List.iter (fun t ->
            if !y > (height / 5) then (
                y := !y - 15;
                G.moveto x !y;
                G.set_color blue;
                G.draw_string t;
                )
            ) info
    ) else (
        G.moveto x (!y-15);
        G.set_color gray;
        G.draw_string "No match"
    )
