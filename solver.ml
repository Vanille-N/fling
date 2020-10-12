module D = Draw

type async_solver = {
    mutable game: Rules.game;
    mutable fork: Rules.move list list;
    mutable found: bool;
    mutable count: int;
}

let solve game = {
    game=game;
    fork=[Rules.moves game];
    found=false;
    count=0;
}

let game solver = solver.game

let count solver = solver.count

let is_solved solver = solver.found

(* let has_extremal g =
    (* criterion: if a ball has an extremum for both its coordinates then there is no solution *)
    let (minx, miny, maxx, maxy) = (ref 100, ref 100, ref (-1), ref (-1)) in
    let (cmnx, cmny, cmxx, cmxy) = (ref 0, ref 0, ref 0, ref 0) in
    List.iter (fun b ->
        let p = Rules.position_of_ball b in
        let x = Position.proj_x p in
        let y = Position.proj_y p in
        if x = !minx then incr cmnx;
        if x = !maxx then incr cmxx;
        if x < !minx then (minx := x; cmnx := 0);
        if x > !maxx then (maxx := x; cmxx := 0);
        if y = !miny then incr cmny;
        if y = !maxy then incr cmxy;
        if y < !miny then (miny := y; cmny := 0);
        if y > !maxy then (maxy := y; cmxy := 0);
        ) (Rules.get_balls g);
    let rec aux = function
        | [] -> true
        | b::tl -> (
            let p = Rules.position_of_ball b in
            let x = Position.proj_x p in
            let y = Position.proj_y p in
            if ((x = !maxx && !cmxx = 1) || (x = !minx && !cmnx = 1))
            && ((y = !maxy && !cmxy = 1) || (y = !miny && !cmny = 1))
            then false
            else aux tl
        )
    in aux (Rules.get_balls g) *)

let is_solved solver = solver.found

let rec leave solver =
    match solver.fork with
        | [] -> failwith "Unreachable @solver::leave::[]"
        | [hd] -> Rules.clear_fwd solver.game
        | hd::tl -> (
            let (g, update) = Rules.undo_move solver.game in
            solver.game <- g;
            List.iter (D.animate_ball 0) update;
            solver.fork <- tl;
            leave solver
            )

let step solver =
    solver.count <- solver.count + 1;
    if solver.found then (
        match solver.fork with
            | [] -> failwith "Unreachable @solver::step::if::[]" (* because we can't undo the move made before solving began *)
            (* we went back to the base level *)
            | [mv] -> Some true
            (* we have some moves to undo *)
            | hd::tl ->
                let (g, update) = Rules.undo_move solver.game in
                solver.game <- g;
                List.iter (D.animate_ball 0) update;
                solver.fork <- tl;
                None
    ) else (
        match solver.fork with
            | [] -> failwith "Unreachable @solver::step::else::[]" (* same reason as above *)
            (* all paths were explored *)
            | []::[] -> Some false
            (* there are no possible paths left and no solution was found *)
            | []::tl -> (
                (* there are no possible moves left for this configuration *)
                if Rules.is_win solver.game then (
                    solver.found <- true;
                    None
                ) else (
                    let (g, update) = Rules.undo_move solver.game in
                    solver.game <- g;
                    List.iter (D.animate_ball 0) update;
                    solver.fork <- tl;
                    None
                )
            )
            | (m::more)::tl -> (
                (* m is a possible unexplored move *)
                let (g, update) = Rules.apply_move solver.game m in
                solver.game <- g;
                List.iter (D.animate_ball 0) update;
                solver.fork <- (Rules.moves solver.game)::more::tl;
                None
            )
    )
