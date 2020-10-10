# Fling

[Neven Villani](https://github.com/Vanille-N), ENS Paris-Saclay

Implementation of the "Fling" puzzle game

## Build and launch

Requires `ocamlbuild`

```
$ make && ./fling
```
Then follow instructions.

## Major design choices
By decreasing importance

#### Dematerialized balls

The decicion most impactful to the rest of the project was the choice to make `game` store information on the balls only in a dematerialized manner. There is no actual `ball` used by `game`, `ball` only serves for interfacing with `game.ml`.

```ocaml
type game = {
    balls: (int, Position.t) Hashtbl.t; (* direct access id -> position *)
    grid: (Position.t, int) Hashtbl.t; (* direct access position -> id *)
    (* other fields irrelevant *)
}
```

Instead of being a `ball list`, `game` is basically a `(Position.t, int) Hashtbl.t * (int, Position.t) Hashtbl.t` (with some more auxiliary information).

Advantages:
- `is_ball` is a simple O(1) hashtable lookup
- so is `ball_of_position`
- alternating between iterations on balls and positions as done in moves is straightforward as well
- although `get_balls` is not as immediate as if `game` were a `ball list`, it remains easy

Drawbacks:
- `game`s cannot be thoughtlessy moved around: deep copies may be costly and shallow copies may lead to unexpected side effects
- a `ball` can record a position that is out of sync with the actual `game`, as `game` may hold information that has not been propagated to all balls still existing (this has been the cause of a difficult to track down bug when trying to implement the behavior described in the section about `redraw_game`)
- every new information requires updating two hashtables, failure to update one of them may lead to bugs that are extremely hard to identify. I have done my best not to separate related updates: calls to any of `Hashtbl.add`, `Hashtbl.remove`, `Hashtbl.update` are grouped together on consecutive lines.

Altogether, performance of `is_ball` and `ball_of_position` was the main deciding factor.
Other options have been considered (and rejected):
- `type game = ball list` has poor `ball_of_position` efficiency and it is hard to list all balls on a line/column
- `type game = { by_line: ball list; by_column: ball list; }` solves the "list all balls on a line/column" problem, but is even harder and costly to update than both previous options
- `type game = ball option array array` makes it extremely costly to list all balls, unless paired with a `ball -> Position.t` lookup table, which basically brings us back to the `Hashtbl` option

#### Displacement, undo, redo

```ocaml
type displacement = {
    id: int; (* ball that was displaced *)
    old_pos: Position.t;
    new_pos: Position.t option;
}

type game = {
    mutable hist: displacement list; (* history of all previous moves *)
    mutable fwd: displacement list; (* history of undone moves *)
    (* other fields irrelevant *)
}
```

A `displacement` holds information on a single movement of a single ball. A movement by the user triggers at least two `displacement`s, as at least one ball is hit in addition to the initial ball.

All `displacement`s are stored sequentially in `game` in order to allow restoring the game to any previous state.

The `new_pos` field is `None` when the ball went off the edge of the grid, which leads to the following remark: any displacements caused by a single user move are stored sequentially in `hist` between two displacements with `None` for their `new_pos`.

To undo a move, we simply pop from the `game.hist` stack until either the end or a second `None`. All `displacement`s obtained in this manner are rolled back in turn then added to the top of `fwd` in order to allow redoing a move symetrically.

Having `hist` and `fwd` as `displacement list list` would have spared us from this process of looking for the last `displacement` of a `move`, but pushing to `hist` and `fwd` would have been less straightforward. In particular, it would have required a lot more logic in `apply_move`, which is complicated enough as is.
