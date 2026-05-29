# NeXTspim

NeXTspim is a NeXT-style AppKit front end for SPIM, James Larus's MIPS
R2000/R3000 simulator.  It runs MIPS assembly programs, displays registers,
text and data segments, provides a console, and includes debugger-oriented
controls such as stepping, breakpoints, and register editing.

## History

SPIM was originally written by James Larus as a self-contained simulator for
the MIPS R2000/R3000 architecture.  It can read and run assembly language
programs and implements most of the assembler-extended MIPS instruction set.
The code in this repository is based on SPIM 5.0-era sources and includes the
optional cycle-level SPIM support by Anne Rogers and Scott Rosenberg.

Mark Gritter ported the XSPIM interface to NeXTstep in the early 1990s.  The
original `Documentation/NeXTspim-1.0.README` describes NeXTspim as a NeXTstep
2.1 application with almost all of the functionality of `cl-spim` and
`cl-xspim`, packaged with user documentation and programmer notes.

This repository is a modern source port of that NeXTstep application.  The UI
has been moved to Cocoa/GNUstep AppKit APIs, and the original Interface Builder
`.nib` has been replaced with programmatic window and menu construction so the
application can be built directly from source.

### This application was ported to macOS and GNUstep by Gregory Casamento

I have been working on this for a bit, but was stuck.   I relied on generative
AI to translate some of the things I couldn't figure out.  My email address
is greg.casamento@gmail.com.

## Current Application

The current build produces `NeXTspim.app` on macOS and a GNUstep-style
application wrapper on systems with GNUstep installed.  The main window is
assembled in code and contains:

- a toolbar for loading programs, running, stepping, clearing state, and opening
  breakpoints;
- editable main and general-purpose register fields;
- a text segment view with the current program counter highlighted;
- a data/stack/kernel-data view;
- a console view backed by a keyboard input queue.

Preferences control simulator options such as bare-machine mode, loading the
default trap handler, hexadecimal register display, memory-mapped I/O, and the
UI update interval.  Cycle-level cache, TLB, and pipeline controls are still
guarded by `CL_SPIM` conditionals.

## Repository Structure

- `NeXTspim_main.m` starts `NSApplication`, installs the AppKit delegate,
  locates bundled resources such as `trap.handler`, initializes SPIM, and
  enters the application run loop.
- `SPIMInterface.[hm]` builds the main menu and main window programmatically,
  connects AppKit actions to simulator commands, and renders registers, text,
  data, cache, and pipeline state.
- `RunLoop.[hm]` provides the pthread-backed simulator execution loop and the
  mutex/condition wrappers used to coordinate the UI thread with the simulation
  thread.
- `TextView.[hm]`, `CodeView.[hm]`, `ConsoleView.[hm]`, and `ConsoleText.[hm]`
  implement the AppKit text surfaces used by the code, data, and console panes.
- `KeyQueue.[hm]` buffers console keyboard input for simulated programs.
- `PrefsPanel.[hm]`, `BreakpointsPanel.[hm]`, `ContinuePanel.[hm]`, and
  `StatsWindow.[hm]` implement the auxiliary panels and statistics windows.
- `data.*`, `inst.*`, `mem.*`, `run.*`, `sym-tbl.*`, `spim-utils.*`,
  `mips-syscall.*`, `read-aout.*`, `scanner.*`, `parser.*`, `lex.yy.c`, and
  `y.tab.*` are the SPIM assembler, loader, memory, instruction, syscall,
  parser, and execution engine sources.
- `cl-cache.*`, `cl-cycle.*`, `cl-except.*`, and `cl-tlb.*` are the optional
  cycle-level SPIM support sources.
- `trap.handler` is the default SPIM trap handler bundled with the app.
- `Info.plist`, `Info-gnustep.plist`, `NeXTspim.desktop`, `spim.tiff`,
  `NeXTspim.icns`, and `NeXTspim.iconset/` are application metadata and visual
  resources.
- `Documentation/` contains the original NeXTspim README, user documentation,
  programmer notes, and the SPIM/cycle-level PostScript manuals.
- `Makefile` builds the executable and application wrapper for either macOS or
  GNUstep.  `Makefile.preamble` is a legacy build fragment that records the
  historical `-DBIGENDIAN -DCL_SPIM` configuration.

Generated files such as object files, `NeXTspim`, and `NeXTspim.app` are ignored
by git.

## Building

On macOS with the command line tools installed:

```sh
make
make run
```

On GNUstep systems, install the GNUstep base, GUI, and make packages first.
The same `make` target uses `gnustep-config` when it is available.

The build copies `trap.handler`, the TIFF icon, and selected documentation into
the application wrapper so the simulator can find its runtime resources from
inside the bundle.

## Documentation

The historical documentation is still useful for understanding both the user
interface and the porting decisions:

- `Documentation/NeXTspim-1.0.README` gives the original release overview.
- `Documentation/NeXTspim.doc.rtf` is the original user documentation.
- `Documentation/NeXTspim.rtf` contains programmer notes, known issues, and
  NeXT-specific implementation details.
- `Documentation/spim.ps` and `Documentation/cycle.ps` are the SPIM and
  cycle-level SPIM manuals.

## Credits and Copyright

SPIM was written by James Larus.  Cycle-level SPIM support was written by Anne
Rogers and Scott Rosenberg.  The NeXTstep interface was written by Mark Gritter.

The original source files carry their own copyright and redistribution terms.
In brief, SPIM may be copied and modified for personal use, copyright notices
must be retained, and commercial distribution requires written permission from
James Larus.  See the source headers and bundled documentation for the complete
terms.
