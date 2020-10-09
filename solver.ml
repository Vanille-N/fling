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

let step solver =
    solver.count <- solver.count + 1;
    if solver.found then (
        match solver.fork with
            | [] -> failwith "Unreachable @solver::step::if::[]" (* because we can't undo the move made before solving began *)
            (* we went back to the base level *)
            | [mv] -> Some true
            (* we have some moves to undo *)
            | hd::tl ->
                solver.game <- Rules.undo_move solver.game;
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
                    solver.game <- Rules.undo_move solver.game;
                    solver.fork <- tl;
                    None
                )
            )
            | (m::more)::tl -> (
                (* m is a possible unexplored move *)
                solver.game <- Rules.apply_move solver.game m;
                solver.fork <- (Rules.moves solver.game)::more::tl;
                None
                )
    )
