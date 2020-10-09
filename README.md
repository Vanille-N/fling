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

```
Then follow instructions.
