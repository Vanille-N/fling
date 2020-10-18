# Fling

[Neven Villani](https://github.com/Vanille-N), ENS Paris-Saclay
October 2020

Implementation of the "Fling" puzzle game

## Outline

[0. Build targets](#0-build-targets)
[1. Major design choices](#1-major-design-choices)
- [1.a. Dematerialized balls](#1a-dematerialized-balls)
- [1.b. Displacement, undo, redo](#1b-displacement-undo-redo)
- [1.c. Asynchronous game solver](#1c-asynchronous-game-solver)

[2. Some additions](#2-some-additions)
- [2.a. Movement animations, efficient redraw](#2a-movement-animations-efficient-redraw)
- [2.b. Trimming the solver's tree](#2b-trimming-the-solvers-tree)
- [2.c. Load/Save menu](#2c-loadsave-menu)
- [2.d. Edit replay or loaded file](#2d-edit-replay-or-loaded-file)
- [2.e. Game controls and help messages](#2e-game-controls-and-help-messages)
- [2.f. Prettify balls display](#2f-prettify-balls-display)
- [2.g. Remove ball when in game creation phase](#2g-remove-ball-when-in-game-creation-phase)
- [2.h. Event synchronization](#2h-event-synchronization)
- [2.i. Optional rule for adjacent balls](#2i-optional-rule-for-adjacent-balls)

[3. TLDR](#3-tldr)

[4. Thoughts](#4-thoughts)

## 0. Build targets
[^Up](#fling)

Requires `ocamlbuild`

To build: `$ make`, then follow instructions to set game controls.

To build and run: `$ make run`, then follow instructions to set game controls and play

To generate and open documentation in default browser: `$ make doc`, directory is `fling.docdir`

To compress: `$ make tar`

To clean build artifacts: `$ make clean`

## 1. Major design choices
[^Up](#fling)
By decreasing importance

#### 1.a. Dematerialized balls
[^Up](#fling)

The decicion most impactful to the rest of the project was the choice to make `game` store information on the balls only in a dematerialized manner. There is no actual `ball` being used in `rules.ml`, `ball` only serves for interfacing with `game.ml` and `draw.ml`. Moreover, a `ball` carries no information on its position, and it only has a position relative to a `game`.

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
- `game`s cannot be thoughtlessy moved around: deep copies may be costly and shallow copies may lead to side effects;
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

Thanks to `undo_move`/`redo_move`, the user can be put in control of a game state where a sequence of moves leading to the solution has been memorized in the `fwd` field of `game`. Pressing the keys associated with undo/redo allows for exploring the solution.

## 2. Some additions
[^Up](#fling)
By decreasing complexity

#### 2.a. Movement animations, efficient redraw
[^Up](#fling)

One obstacle to smooth animations was the inefficiency of `draw_game`. Each call to it would redraw the whole board, which caused graphical issues.

Before I could hope to have a smooth animation, I needed to tweak `draw.ml` to allow redrawing only as much as necessary: erase the ball, redraw the grid square closest to it, redraw the new ball. Nothing more. This is what each iteration of the main loop of `animate_ball` does. A small delay is introduced to adjust the speed of the balls.

#### 2.b. Trimming the solver's tree
[^Up](#fling)

One single criterion for eliminating configurations guaranteed to be unsolvable was implemented.

It consists in checking if any ball is outside of the rectangular zone containng all other balls. One can easily see that any move will cause all balls still in game to remain inside said rectangular region. This translates to finding `b` so that `((∀b', b.x < b'.x) || (∀b', b.x > b'.x)) && ((∀b', b.y < b'.y) || (∀b', b.y > b'.y))`

The efficient method for checking it is:
- find the maximum and minimum for `x` and `y`, and how many times they appear
- check if any ball satisfies that both of its coordinates are the maximum/minimum and if there is only one of that maximum/minimum.

The whole cost is linear relative to the number of balls still in game. I don't think it improves the worst case complexity of the solver, but it has been proven to be very effective on configurations such as `no_solution_3`.

#### 2.c. Load/Save menu
[^Up](#fling)

The load/save menu reads keyboard input and returns the string entered by the user. As its name implies, it can be accessed either when writing a file (press on the set key when a game is running) or when loading a file (3rd menu option).

Text entered by the user is displayed in real time and compared against names of files already existing in `.data/`. The menu supports deletion (Backspace) and cyclic autocompletion (Tab). When Enter is pressed, the text displayed is treated as a filename and checked against `^[a-zA-Z0-9\.\-_]+$`.

#### 2.d. Edit replay or loaded file
[^Up](#fling)

This required a bit of change in `game.ml`'s toplevel. The global variable `game : game` was replaced with `balls : (ball, Position.t) list`. The `add_balls` function also can be run from more places.

Together these changes allow editing the game that was last played or a save file. Before this the `replay` menu option started the game immediately and so did the `load file` one. Now one can load a file then modify the balls' position before playing.

#### 2.e. Game controls and help messages
[^Up](#fling)

Since many events are keyboard-controlled, two things were made to make it easier to play the game.

First, the user can choose custom controls through the command line.
During the first build (`$ make` or `$ make run`), the user will be promted to enter controls for movement and control keys.
The initialization process is external to OCaml, but the addition in the header of `game.ml` of constants to record the key associated to each control and the modification of some places (`create_game` and `get_ball_direction`) to use these constants instead of hardcoded keys make this behavior possible.

For the record, the automatic tool is `.chctrls` and it is written in Bash, with Perl and Sed doing the heavy lifting. If for some reason you don't have access to one of these, you should edit the keys manually in `game.ml`.

During the game, the text zone (upper left) displays usable keys for:
- when creating the game: start game, remove ball
- when a ball is selected: left, right, up, down (if allowed), cancel
- when no ball is selected: undo, redo (if allowed), solve, exit (to menu), write (saves the game), forcequit (kills the program)

#### 2.f. Prettify balls display
[^Up](#fling)

As was suggested in the handout, drawing a simple circle for a ball is visually unappealing.
The new and improved ball drawing function draws several slightly off-center circles with a gradient to give an impression of volume.
To not put too much burden on the drawer in the solving phase, the number of circles can be adjusted to lower the quality but improve the drawing speed.
The original drawing function is a special case of the new one when the number of circles to draw passed as parameter is 1.

#### 2.g. Remove ball when in game creation phase
[^Up](#fling)

The original version of `create_game` did not allow for removing a ball.
In the event of a misclick, one would have to exit the game creation phase, and restart from scratch.
The ergonomics of game creation were improved by allowing the user to remove a ball when pointing at it and pressing Backspace.

#### 2.h. Event synchronization
[^Up](#fling)

Once the animations were done a problem popped up: holding down a key ('undo' for example) would generate keyboard events faster than the animations would allow the game loop to react to these events. This would cause the event queue to grow in size and the game would then become unplayable for a long time until all events had been taken care of.

To solve this it became necessary to empty the event queue after each executed input. Fortunately this required only minor modifications to the project skeleton.

#### 2.i. Optional rule for adjacent balls
[^Up](#fling)

The rules state that when two balls are adjacent, one may not be launched against the other. This in particular makes the full grid unsolvable.
Since I like being able to ignore this rule, I decided to add a boolean variable at the top of `game.ml` which when true allows throwing a ball against a direct neighbor.

## 3. TLDR
[^Up](#fling)

In short:
- `game` is a pair of `Hashtbl`s, which allows for efficient lookup;
- `ball` holds no information and is only usable relative to a `game`;
- `game` stores information on which moves to undo/redo if wanted;
- `solve` is asynchronous to enable real-time feedback;
- the solving process was integrated with the main game;
- ergonomics of load/write/edit were improved;
- more keyboard controls were added and help messages are shown;
- visuals (graphics and animations) were greatly improved;
- you can play by your preferred game variant.

## 4. Thoughts
[^Up](#fling)

There are only three things I am mildly dissatisfied with, not necessarily in direct relation to this project in particular, rather to it being my first sizeable compiled project in OCaml:

- Some aspects of the code are rightfully functionnal -- the game loop/main menu which make good use of tail call optimization; most utilities in `rules.ml`; `create_game` -- but seamless integration with the graphical interface led to some amount of code that I wouldn't have written much differently in any imperative language.
Notable examples are `get_filename` and `solver`.
Some of this is also due to the choice of `Hashtbl`s for `game`, which being mutable inevitably led to an imperative-style `apply_move` (although the loop is recursive), in which there are more `:=` and `<-` than `|>`.
At the same time there are some places where doing a `while` loop with a recursive function just for the sake of it didn't seem like a good idea. For example, in `loop`, there are 6 different cases, and only one of them causes the end of the loop. Having `stay := false` once rather than `aux game` five times just seemed more readable.
In short, I used functional style whenever it seemed appropriate, but I didn't go out of my way to remove all `ref`, `for` and `while`.<br><br>

- I feel like both `game.ml` and `rules.ml` have become too big and I would have liked to split them into submodules or take out some utilities, but I was sometimes restricted by OCaml's inability to handle cyclic dependencies and by the dilemma of keeping the type internals private.
Here's a concrete example: I would have liked to extract `get_filename`, `write_game`, `load_game`, `write_file`, `load_file` into a single module dedicated to file IO. Unfortunately `load_game` and `write_game` must know of the `game` internals, and `get_filename` has to be able to call functions from `draw.ml`, which the level of `rules.ml` doesn't allow.
`load_file` and `write_file` must also know of `loop` and `main`. Since `game.ml` is the highest module in the dependency tree, it is hard to do without splitting these related functions between multiple files.
Workarounds can be found, like passing continuation functions as parameters, but it quickly becomes overdone. Putting each function where it has the visibility it needs does not make for a satisfying structure, but it is the easiest way.<br><br>

- I don't really like OCaml's build process and error messages.
The type checker is certainly useful, but the absence of type indicators on function signatures makes for errors that are a few steps too late (I might try to address this issue next time by adding type hints to function arguments).
Mismatched types in function A leads to wrong type inference in function B which leads to a type error in function C. Having to guess from the error message that the actual issue lies in A, 50 lines before the line displayed on the error message is sometimes frustrating.
To this is added the fact that the lack of clear end-of-function delimiters leads to missing parentheses causing syntax errors on the start of the next function definition. Because of this, error messages are often useless, or to be taken with a grain of salt.
`ocamlbuild` feels hackish as well, although it is easier to deal with than `ocamlc`.

That being said, I very much enjoyed working with the graphical interface, which is something I had never done either in OCaml or at this level with only drawing primitives. My previous experience with graphics libraries is restricted to Python's TkInter and Matplotlib and C++'s Qt, all of which have higher-level drawing APIs and more convoluted event management. Altogether I had a lot of fun implementing this project.
