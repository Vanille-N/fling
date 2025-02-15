# Fling

[Neven Villani](https://github.com/Vanille-N), ENS Paris-Saclay
October 2020

Implementation of the "Fling" puzzle game

<!-- This file is best viewed in a Markdown renderer at least as complete as Github's -->

## Outline

[0. Build targets](#0-build-targets)
[1. Major design choices](#1-major-design-choices)
- [1.a. Dematerialized balls](#1a-dematerialized-balls)
- [1.b. Displacement, undo, redo](#1b-displacement-undo-redo)
- [1.c. Asynchronous game solver](#1c-asynchronous-game-solver)

[2. Some additions and points of interest](#2-some-additions-and-points-of-interest)
- [2.a. Movement animations, efficient redraw](#2a-movement-animations-efficient-redraw)
- [2.b. Trimming the solver's tree](#2b-trimming-the-solvers-tree)
- [2.c. Load/Save menu](#2c-loadsave-menu)
- [2.d. File format](#2d-file-format)
- [2.e. Edit replay or loaded file](#2e-edit-replay-or-loaded-file)
- [2.f. Game controls and help messages](#2f-game-controls-and-help-messages)
- [2.g. Prettify balls display](#2g-prettify-balls-display)
- [2.h. Remove ball when in game creation phase](#2h-remove-ball-when-in-game-creation-phase)
- [2.i. Event synchronization](#2i-event-synchronization)
- [2.j. Optional rule for adjacent balls](#2j-optional-rule-for-adjacent-balls)

[3. TLDR](#3-tldr)

[4. Thoughts](#4-thoughts)

## 0. Build targets
[^Up](#fling)

Requires `ocamlbuild`

Dependencies: `Graphics`, `Unix`.
`Graphics` is not an option, `Unix` can be avoided if one (un)comments the required lines at the end of `rules.ml` (grep for 'Unix').

To build: `$ make`, then follow instructions to set game controls.

To build and run: `$ make run`, then follow instructions to set game controls and play

To generate and open documentation in default browser: `$ make doc`, directory is `fling.docdir`

To compress: `$ make tar` (will fail with the modified layout if `README.md` is not in the same directory as the rest)

To clean build artifacts: `$ make clean`

## 1. Major design choices
[^Up](#fling)
By decreasing importance

#### 1.a. Dematerialized balls
[^Up](#fling)

The decicion most impactful to the rest of the project was the choice to make `game` store information on the balls only in a dematerialized manner. There is no actual `ball` being used in `rules.ml`, `ball` only serves for interfacing with `game.ml` and `draw.ml`. Moreover, a `ball` carries no information on its position, and it only has a position relative to a `game`.

```ocaml
type game = {
    balls: (ball, Position.t) Hashtbl.t; (* direct access id -> position *)
    grid: (Position.t, ball) Hashtbl.t; (* direct access position -> id *)
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
- `type game = ball list` has poor `ball_of_position` efficiency and it is harder to list all balls on a line/column
- `type game = { by_line: ball list array; by_column: ball list array; }` solves the "list all balls on a line/column" problem, but is even more difficult to update than both previous options
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

One notable advantage is the possibility of implementing an "abort solution search on keypress" functionality, that would be virtually impossible to implement cleanly (i.e. without blurring the line between event management and the solver logic) were `solve` blocking all computation until a solution was found.

Thanks to `undo_move`/`redo_move`, the user can be put in control of a game state where a sequence of moves leading to the solution has been memorized in the `fwd` field of `game`. Pressing the keys associated with undo/redo allows for exploring the solution.

## 2. Some additions and points of interest
[^Up](#fling)
By decreasing complexity

#### 2.a. Movement animations, efficient redraw
[^Up](#fling)

One obstacle to smooth animations was the inefficiency of `draw_game`. Each call to it would redraw the whole board, which caused graphical issues.

Before I could hope to have a smooth animation, I needed to tweak `draw.ml` to allow redrawing only as much as necessary: erase the ball, redraw the grid square closest to it, redraw the new ball. Nothing more. This is what each iteration of the main loop of `animate_ball` does. A small delay is introduced to adjust the speed of the balls.

After each movement, a list of balls to update is created. It indicates which balls are involved, what were their starting positions, and where they are now. `draw.ml` takes such list and animates each movement in turn.

#### 2.b. Trimming the solver's tree
[^Up](#fling)

One single criterion for eliminating configurations guaranteed to be unsolvable was implemented.

It consists in checking if any ball is outside of the rectangular zone containng all other balls. One can easily see that any move will cause all balls still in game to remain inside said rectangular region. This translates to finding `b` so that `((∀b', b.x < b'.x) || (∀b', b.x > b'.x)) && ((∀b', b.y < b'.y) || (∀b', b.y > b'.y))`

The efficient method for checking it is:
- find the maximum and minimum for `x` and `y`, and how many times they appear
- check if any ball satisfies that both of its coordinates are the maximum/minimum and if there is only one of that maximum/minimum.

The whole process costs a linear amount of time relative to the number of balls still in game. I don't think it improves the worst case complexity of the solver, but it has been proven to be very effective on configurations such as `square-and-corner`.

One possible improvement would be to extend this criterion to cover the case when the balls can be divided into two groups such that the maximum y-coordinate of one group is more than the minimum y-coordinate of the other group, and the same is true of the x-coordinates.

#### 2.c. Load/Save menu
[^Up](#fling)

The load/save menu reads keyboard input and returns the string entered by the user. As its name implies, it can be accessed either when writing a file (press on the set key when a game is running) or when loading a file (3rd menu option).

Text entered by the user is displayed in real time and compared against names of files already existing in `.data/`. The condition for a file to appear is that 1) the text must be a (not necessarily contiguous) subsequence of that name and 2) it should not start with a `.` unless the text also does.
The menu supports deletion (Backspace) and cyclic autocompletion (Tab). When Enter is pressed, the text displayed is treated as a filename and checked against `^[a-zA-Z0-9\.\-_]+$`. Esc allows to cancel.

#### 2.d. File format
[^Up](#fling)

There are two file formats available.
- `v0`: a list of positions `"{x} {y}\n"`
- `v1`: a square matrix of `.` (empty) and `*` (ball)

The encoder calculates both representations and chooses the shortest one in terms of line count.
Were space efficiency a concern, I would have made the representation more compact, the goal here is to improve readability. When there are many balls, the matrix representation is better, but a list of positions is fine if there are fewer balls than lines on the grid.

The decoder starts by reading the format indicator and dispatches to the corresponding decoding function.

All of this wasn't really necessary. I just created my file format anticipating that I should leave room for defining several encodings or versions thereof to guarantee backwards compatibility with files already created, and I didn't want to let it go to waste.

I also added a header that includes the date when the file was created. (There lies the dependency to `Unix`, it should be considered more of a gimmick to have fun with the standard library)

#### 2.e. Edit replay or loaded file
[^Up](#fling)

This required a bit of change in `game.ml`'s toplevel. The global variable `game : game` was replaced with `balls : (ball, Position.t) list`. The `add_balls` function also can be run from more places.

Together these changes allow editing the game that was last played or a save file. Before this the `replay` menu option started the game immediately and so did the `load file` one. One can now load a file then modify the balls' position before playing.

#### 2.f. Game controls and help messages
[^Up](#fling)

Since many events are keyboard-controlled, two things were made to make it easier to play the game.

First, the user can choose custom controls through the command line.
During the first build (`$ make` or `$ make run`), the user will be promted to enter controls for movement and control keys.
The initialization process is external to OCaml, but the addition in the header of `game.ml` of constants to record the key associated to each control and the modification of some places (`create_game` and `get_ball_direction`) to use these constants instead of hardcoded keys make this behavior possible.

For the record, the automatic tool is `.chctrls` and it is written in Bash, with Perl and Sed doing the heavy lifting. If for some reason you don't have access to one of these, you should edit the keys manually in `game.ml`. After running it creates a marker file `.ctrlset` so that it is executed only once.

During the game, the text zone (upper left) displays usable keys for:
- when creating the game: start game, remove ball
- when a ball is selected: left, right, up, down (if allowed), cancel
- when no ball is selected: undo, redo (if allowed), solve, exit (to menu), write (saves the game), forcequit (kills the program)

#### 2.g. Prettify balls display
[^Up](#fling)

As was suggested in the handout, drawing a simple circle for a ball is visually unappealing.
The new and improved ball drawing function draws several slightly off-center circles with a gradient to give an impression of volume.
To not put too much burden on the drawer in the solving phase, the number of circles can be adjusted to lower the quality but improve the drawing speed.
The original drawing function is a special case of the new one when the number of circles to draw passed as parameter is 1.

#### 2.h. Remove ball when in game creation phase
[^Up](#fling)

The original version of `create_game` did not allow for removing a ball.
In the event of a misclick, one would have to exit the game creation phase, and restart from scratch.
The ergonomics of game creation were improved by allowing the user to remove a ball when pointing at it and pressing Backspace.

#### 2.i. Event synchronization
[^Up](#fling)

Once the animations were done a problem popped up: holding down a key ('undo' for example) would generate keyboard events faster than the animations would allow the game loop to react to these events. This would cause the event queue to grow in size and the game would then become unplayable for a long time until all events had been taken care of.

To solve this it became necessary to empty the event queue after each executed input. Fortunately this required only minor modifications to the project skeleton.

#### 2.j. Optional rule for adjacent balls
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

- Most of the code is written in functionnal style, but the interfaces for `game` and `solver` require a certain amount of code with side effects due to the mutable nature of objects involved.

- I feel like both `game.ml` and `rules.ml` have become too big and I would have liked to split them into submodules or take out some utilities, but I was sometimes restricted by OCaml's inability to handle cyclic dependencies and by the dilemma of keeping the type internals private. Otherwise I would have made files of 150~200 lines, not 350~400.

- I don't really like OCaml's build process and error messages. The absence of type indicators on function signatures combined with the lack of clear end-of-function delimiters leads to error messages that indicate the error line a lot later than where the actual issue is.

That being said, I very much enjoyed working with the graphical interface, which is something I had never done either in OCaml or at this level with only drawing primitives. My previous experience with graphics libraries is restricted to Python's TkInter and Matplotlib and C++'s Qt, all of which have higher-level drawing APIs and more convoluted event management. Altogether I had a lot of fun implementing this project.
