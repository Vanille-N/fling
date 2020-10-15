# Fling

[Neven Villani](https://github.com/Vanille-N), ENS Paris-Saclay

Implementation of the "Fling" puzzle game

## Outline

[0. Build targets](#0-build-targets)
[1. Major design choices](#1-major-design-choices)
- [1.a. Dematerialized balls](#1a-dematerialized-balls)
- [1.b. Displacement, undo, redo](#1b-displacement-undo-redo)
- [1.c. Asynchronous game solver](#1c-asynchronous-game-solver)

[2. Some additions](#2-some-additions)

[3. TLDR](#3-tldr)

[4. Thoughts](#4-thoughts)

## 0. Build targets
[^Up](#fling)

Requires `ocamlbuild`

To build: `$ make`, then follow instructions to set game controls.

To build and run: `$ make run`, then follow instructions to set game controls and play

To generate documentation: `$ make doc`, directory is `fling.docdir`

To compress: `$ make tar`

To clean build artifacts: `$ make clean`

## 1. Major design choices
[^Up](#fling)
By decreasing importance

#### 1.a. Dematerialized balls
[^Up](#fling)

The decicion most impactful to the rest of the project was the choice to make `game` store information on the balls only in a dematerialized manner. There is no actual `ball` used by `game`, `ball` only serves for interfacing with `game.ml`. Moreover, a `ball` carries no information on its position, and it only has a position relative to a `game`.

```ocaml
type game = {
    balls: (int, Position.t) Hashtbl.t; (* direct access id -> position *)
    grid: (Position.t, int) Hashtbl.t; (* direct access position -> id *)
    (* -- other fields irrelevant -- *)
}
```

Instead of being a `ball list`, `game` is basically a `(Position.t, int) Hashtbl.t * (int, Position.t) Hashtbl.t` (with some more auxiliary information).

Advantages:
- `is_ball` is a simple O(1) hashtable lookup;
- so is `ball_of_position`;
- alternating between iterations on balls and positions as done in `moves` is straightforward as well;
- although `get_balls` is not as immediate as if `game` were a `ball list`, it remains easy.

Drawbacks:
- `game`s cannot be thoughtlessy moved around: deep copies may be costly and shallow copies may lead to unexpected side effects;
- the `game` must be passed down to function calls, since a `ball` on its own is not enough to know its position;
- every new movement requires updating two hashtables, failure to update one of them may lead to bugs that are extremely hard to identify. I have done my best not to separate related updates: calls to any of `Hashtbl.add`, `Hashtbl.remove`, `Hashtbl.update` are grouped together on consecutive lines.

Altogether, performance of `is_ball` and `ball_of_position` was the main deciding factor.
Other options have been considered (and rejected):
- `type game = ball list` has poor `ball_of_position` efficiency and it is hard to list all balls on a line/column
- `type game = { by_line: ball list array; by_column: ball list array; }` solves the "list all balls on a line/column" problem, but is even harder and costly to update than both previous options
- `type game = ball option array array` makes it extremely costly to list all balls, unless paired with a `ball -> Position.t` lookup table, which basically brings us back to the `Hashtbl` option

#### 1.b. Displacement, undo, redo
[^Up](#fling)

```ocaml
type displacement = {
    id: int; (* ball that was displaced *)
    old_pos: Position.t;
    new_pos: Position.t;
}

type game = {
    mutable hist: displacement list list; (* history of all previous moves *)
    mutable fwd: displacement list list; (* history of undone moves *)
    (* -- other fields irrelevant -- *)
}
```

A `displacement` holds information on a single movement of a single ball. A movement by the user triggers at least two `displacement`s, as at least one ball is hit in addition to the initial ball.

All `displacement`s are stored in `game` in groups triggered by the same user movement in order to allow restoring the game to any previous state.

To undo a move, we simply take the top element from the `game.hist` stack. All `displacement`s obtained in this manner are rolled back in turn then added to the top of `fwd` in order to allow redoing a move symetrically.

#### 1.c. Asynchronous game solver
[^Up](#fling)

Although this one has little impact on the rest of the project, it is the most radical change in terms of difference between the function signature provided in the project skeleton and the actual implementation.

`solve` doesn't actually solve the game ! At least not in a synchronous manner.

Instead it returns an object that "knows" how to solve it, whenever needed.

Each call to `step` will advance the computation by one move (`apply_move` if new moves are available or `undo_move` if a dead-end was reached). This allows showing progress of the computation: the game board is updated and drawn after each attempt at a move. Speed may be adjusted so that the user can see the attempts being made. The user also has access to the number of explored paths in real time in the text section.

One notable advantage is the possibility of implementing an "abort solution search on keypress" functionality, that would be virtually impossible to implement cleanly were `solve` blocking all computation until a solution was found.

The combination of this behavior with `undo_move`/`redo_move` allows for presenting the solution to the user. Instead of simply being told that "the solution exists", the user is put in control of a game state where a sequence of moves leading to the solution has been memorized in the `fwd` field of `game`. Pressing the keys associated with undo/redo allows for exploring the solution.

## 2. Some additions
[^Up](#fling)
By decreasing complexity

#### Movement animations, efficient redraw
#### Event synchronization
#### Load/Save menu
#### Game controls and help messages
#### Prettify balls display
#### Optional rule for adjacent balls

## 3. TLDR
[^Up](#fling)

In short:
- `game` is a pair of `Hashtbl`s, which allows for efficient lookup;
- `ball` holds no information and is only usable relative to a `game`;
- `game` stores information on which moves to undo/redo if wanted;
- `solve` is asynchronous to enable real-time feedback;
- the solving process was integrated with the main game;
- animations were a pain do deal with;
- so were keyboard events;
- I did my best so that load/save would be ergonomic;
- more keyboard controls were added and help messages are shown;
- I had fun with the `ball` graphics;
- you can play by your preferred game variant.

## 4. Thoughts
[^Up](#fling)

There are only three things I am mildly dissatisfied with, not necessarily in direct relation to this project in particular, rather to it being my first sizeable project in OCaml:

- Some aspects of the code are rightfully functionnal -- the game loop/main menu which make good use of tail call optimization; most utilities in `rules.ml`; `create_game` -- but seamless integration with the graphical interface led to some amount of code that I wouldn't have written much differently in any imperative language.
Notable examples are `get_filename` and `solver`.
Some of this is also due to the choice of `Hashtbl`s for `game`, which being mutable inevitably led to an imperative-style `apply_move`, in which there are more `:=` and `<-` than `|>`.

- I feel like both `game.ml` and `rules.ml` have become too big and I would have liked to split them into submodules or take out some utilities, but I was sometimes restricted by OCaml's inability to handle cyclic dependencies and by the dilemma of keeping the type internals private.
Here's a concrete example: I would have liked to extract `get_filename`, `write_game`, `load_game`, `write_file`, `load_file` into a single module dedicated to file IO. Unfortunately `load_game` and `write_game` must know of the `game` internals, and `get_filename` has to be able to call functions from `draw.ml`, which the level of `rules.ml` doesn't allow.
`load_file` and `write_file` must also know of `loop` and `main`. Since `game.ml` is the highest module in the dependency tree, it is hard to do without splitting these related functions between multiple files.
Workarounds can be found, like passing continuation functions as parameters, but it quickly becomes overdone. Putting each function where it has the visibility it needs does not make for a satisfying structure, but it is the easiest way.

- I don't really like OCaml's build process and error messages.
The type checker is incredibly useful, but the absence of type indicators on function signatures makes for errors that are a few steps too late. Mismatched types in function A leads to wrong type inference in function B which leads to a type error in function C. Having to guess from the error message that the actual issue lies in A 50 lines before the line displayed on the error message is sometimes frustrating.
To this is added the fact that the lack of clear end-of-function delimiters leads to missing parentheses causing syntax errors on the start of the next function definition. Because of this error messages are often useless.
`ocamlbuild` feels hackish as well, although it is easier to deal with than `ocamlc`.

On the other hand, I very much enjoyed working with the graphical interface, which is something I had never done either in OCaml or at this level with only drawing primitives. My previous experience with graphics libraries is restricted to Python's TkInter and Matplotlib and C++'s Qt, all of which have higher-level drawing APIs and more convoluted event management. Altogether I had a lot of fun implementing this project.
