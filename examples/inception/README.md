# 6o6 Examples: Inception

## What it is

This example runs on an unmodified Commodore 64 or Commodore 128 in 64 mode, or on an Apple IIe, IIc or IIgs with at least 64K of memory.

Every good virtualizer should be able to virtualize itself, right? Here we prove that the virtualization is sufficiently complete to run 6o6 within 6o6 -- and then run 6o6 within 6o6 within 6o6.

## Building and running

To build the C64 version, type `make c64`. The object is called `incept.prg`. If a directory `../prg/` exists, it will also be copied to it. It is `LOAD`ed and `RUN` like a BASIC program. You can run the program again afterwards.

To build the Apple II version, type `make a2`. The object is called `incept.b`. If [Apple Commander](https://applecommander.github.io/)'s `ac.jar` is in the same directory (a symlink or a copy), a DOS 3.3 disk image called `incept.do` will be generated with the binary. It should be `BRUN` like a binary program (or `BLOAD` and `CALL 2051`). You can run the program again afterwards with `CALL 2051`.

On the Apple II only, the code expands above $9000, which will overwrite some of DOS 3.3's code. You should reboot your Apple II after you've finished exploring the program.

## Technical explanation

Before studying this example, make sure you understand how Hello, World works, since the kernel, harness and payload are exactly the same as the Hello, World example and have the same filenames. Only the main program in `incept.asm`, which we call the "hypervisor," is different.

On startup the kernel, harness, VM and payload are in their expected locations ($0a00, $0b00 and $0c00, and $3800 mapped using the harness to $0a00 in guest memory). This is the same as the Hello, World example, and is our "stage 1."

For stage 2, we now need to get 6o6 to run itself. Because 6o6 uses self-modifying code, we cannot share the same VM, so we copy up a new set. This overlaps stage 1's memory layout by exactly one page, replacing the payload of stage 1 with the kernel for stage 2 and installing a new harness, new VM and new payload higher in memory. The harness computes physical addresses purely by addition, so effectively virtual addresses in stage 2 now get dereferenced twice, adding _two_ offsets. The same process happens for stage 3 with a third copy and three offsets to compute the physical address (see the table at the end if you're unsure how this ends up laid out in RAM).

Similarly, calls to emit a character get propagated up to the next kernel because the same routine gets called, and the terminal `RTS` also gets propagated up, causing each successive kernel to `RTS` as well. It gets a lot slower by the end, but it works! -- just like the movie but with a lot less Michael Caine. At the end the hypervisor copies everything back to their initial locations so you can run it again.

Here's how each stage is laid out in memory (on both platforms):

### Stage 1 (6o6)

0000: 6o6 zero page for stage 1
0100: 6o6 stack for stage 1
0800: "hypervisor"
0a00: 6o6 kernel for stage 1
0b00: 6o6 harness for stage 1
0c00: 6o6 VM for stage 1

3600: payload zero page, mapped to $0000
3700: payload stack, mapped to $0100
3800: payload code, mapped to $0a00

### Stage 2 (6o6 in 6o6)

0000: 6o6 zero page for stage 2
0100: 6o6 stack for stage 2
0800: "hypervisor"
0a00: 6o6 kernel for stage 2
0b00: 6o6 harness for stage 2
0c00: 6o6 VM for stage 2

3600: 6o6 zero page for stage 1, mapped to $0000
3700: 6o6 stack for stage 1, mapped to $0100
3800: 6o6 kernel for stage 1, mapped to $0a00
3900: 6o6 harness for stage 1, mapped to $0b00
3a00: 6o6 VM for stage 1, mapped to $0c00

6400: payload zero page, mapped to $3600, mapped to $0000
6500: payload stack, mapped to $3700, mapped to $0100
6600: payload code, mapped to $3800, mapped to $0a00

### Stage 3 (6o6 in 6o6 in 6o6)

0000: 6o6 zero page for stage 3
0100: 6o6 stack for stage 3
0800: "hypervisor"
0a00: 6o6 kernel for stage 3
0b00: 6o6 harness for stage 3
0c00: 6o6 VM for stage 3

3600: 6o6 zero page for stage 2, mapped to $0000
3700: 6o6 stack for stage 2, mapped to $0100
3800: 6o6 kernel for stage 2, mapped to $0a00
3900: 6o6 harness for stage 2, mapped to $0b00
3a00: 6o6 VM for stage 2, mapped to $0c00

6400: 6o6 zero page for stage 1, mapped to $3600, mapped to $0000
6500: 6o6 stack for stage 1, mapped to $3700, mapped to $0100
6600: 6o6 kernel for stage 1, mapped to $3800, mapped to $0a00
6700: 6o6 harness for stage 1, mapped to $3900, mapped to $0b00
6800: 6o6 VM for stage 1, mapped to $3a00, mapped to $0c00

9200: payload zero page, mapped to $6400, mapped to $3600, mapped to $0000
9300: payload stack, mapped to $6500, mapped to $3700, mapped to $0100
9400: payload code, mapped to $6600, mapped to $3800, mapped to $0a00

## Using this in your own code

Probably not a lot of practical usage for it, but it sure can be fun for blog posts!
