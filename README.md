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

The decicion most impactful to the rest of the project was the choice to make `game` store information on the balls only in a dematerialized manner. There is no actual `ball` used by `game`, `ball` only serves for interfacing with `game.ml`. Moreover, a `ball` carries no information on its position, and it only has a position relative to a `game`.

```ocaml
type game = {
    balls: (int, Position.t) Hashtbl.t; (* direct access id -> position *)
    grid: (Position.t, int) Hashtbl.t; (* direct access position -> id *)
    (* other fields irrelevant *)
}
```

Instead of being a `ball list`, `game` is basically a `(Position.t, int) Hashtbl.t * (int, Position.t) Hashtbl.t` (with some more auxiliary information).

Advantages:
- `is_ball` is a simple O(1) hashtable lookup;
- so is `ball_of_position`;
- alternating between iterations on balls and positions as done in moves is straightforward as well;
- although `get_balls` is not as immediate as if `game` were a `ball list`, it remains easy.

Drawbacks:
- `game`s cannot be thoughtlessy moved around: deep copies may be costly and shallow copies may lead to unexpected side effects;
- the `game` must be passed down to function calls, since a `ball` on its own is not enough to know its position;
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
    new_pos: Position.t;
}

type game = {
    mutable hist: displacement list; (* history of all previous moves *)
    mutable fwd: displacement list; (* history of undone moves *)
    (* other fields irrelevant *)
}
```

A `displacement` holds information on a single movement of a single ball. A movement by the user triggers at least two `displacement`s, as at least one ball is hit in addition to the initial ball.

All `displacement`s are stored in `game` in groups triggered by the same user movement in order to allow restoring the game to any previous state.

To undo a move, we simply take the top element from the `game.hist` stack. All `displacement`s obtained in this manner are rolled back in turn then added to the top of `fwd` in order to allow redoing a move symetrically.

#### Asynchronous game solver

Although this one has little impact on the rest of the project, it is the most radical change in terms of difference between the function signature provided in the project skeleton and the actual implementation.

`solve` doesn't actually solve the game ! At least not in a synchronous fashion.

Instead it returns an object that "knows" how to solve it, whenever needed.

Each call to `step` will advance the computation by one move (`apply_move` if new moves are available or `undo_move` if a dead-end was reached). This allows showing progress of the computation: the game board is updated and drawn after each attempt at a move. The user may also see the number of explored paths in real time in the text section.

One notable advantage is the possibility of implementing an "abort solution search" functionality, that would be virtually impossible to implement cleanly were `solve` blocking all computation until a solution was found.

The combination of this behavior with `undo_move`/`redo_move` allows for presenting the solution to the user. Instead of simply being told that "the solution exists", the user is put in control of a game state where a sequence of moves leading to the solution has been memorized in the `fwd` field of `game`. Pressing the keys associated with undo/redo allows for exploring the solution.

## Some additions
By decreasing complexity

#### Game controls and help messages
#### Prettier display for balls, animations
#### Optional rule
