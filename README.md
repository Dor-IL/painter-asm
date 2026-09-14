# tasm-painter

A mouse-driven paint program for DOS, written in x86 assembly (VGA mode
13h, 320x200x256) and built with Turbo Assembler.

## Building and running

Requires the Borland TASM/TLINK toolchain and a DOS environment (e.g.
DOSBox-X). With `painter.asm` on a mounted DOS drive:

```
TASM painter.asm
TLINK painter.obj
painter.exe
```

A mouse driver must be loaded (e.g. `CTMOUSE.COM`) before running.
