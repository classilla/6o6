# 6o6 Examples: Tasks

## What it is

This example runs on an unmodified Commodore 64 or Commodore 128 in 64 mode, or on an Apple II+, IIe, IIc or IIgs with at least 64K of memory.

It runs two independent tasks, one that prints the alphabet in sequence in normal video, and one that prints digits in sequence in reverse video. Each task has its own zero page and stack. The tasks switch when you press a key, and switch back and forth as you hold down a key.

This is a good template to consider if you want to use 6o6 as part of a multitasking/multithreaded package.

## Building and running

To build the C64 version, type `make c64`. The object is called `tasks.prg`. If a directory `../prg/` exists, it will also be copied to it. It is `LOAD`ed and `RUN` like a BASIC program. This example runs until you stop it with RUN-STOP/RESTORE. You can run the program again afterwards.

To build the Apple II version, type `make a2`. The object is called `tasks.b`. If [Apple Commander](https://applecommander.github.io/)'s `ac.jar` is in the same directory (a symlink or a copy), a DOS 3.3 disk image called `incept.do` will be generated with the binary. It should be `BRUN` like a binary program (or `BLOAD` and `CALL 2051`). This example runs until you stop it with Control-Break. You can run the program again afterwards with `CALL 2051`.

On the C64 only, it is possible to interrupt the numerals task after it emits the RVS ON character, but before it sends a digit and RVS OFF. This shall be considered evidence of preemption.

## Technical explanation

Be sure to understand the basics in Hello, World first, since this example uses similar code.

The harness in `harness.asm` and `harness.def` defines a very simple memory model for each task that contains just 768 bytes each (three pages). Each task has a zero page, a stack and 256 bytes of code, all contiguous from virtual addresses $0000-$02ff, and the payload in each task's virtual address space starts at $0200. Attempts to access virtual addresses greater than $02ff will cause a protection fault exception. A single flag byte indicates which task is "on processor," 0 (alphabet) or 1 (digits). The harness computes the physical address by adding the task number three times and then the physical bottom of emulated RAM to the high byte. For stack pulls and pushes, those routines in the harness simply pick a different offset based on the task number. Although the harness here also can detect stack overflow and underflow, neither will happen in this example under normal circumstances.

The kernel is in `tasks.asm`. Each process has a separate CPU state (A, X, Y, P, S and PC). Both are initialized to start from $0200 and task 0 is put "on processor." If a key is detected (or a key is being held down and the computer sends another keypress), the kernel will save the current CPU task state and replace it with the other one. In this example we just manually load and store each byte of the CPU state, but a small loop could suffice as well. The kernel still intercepts the ROM character print routine; because we don't call the VM with that PC, there is no fetch and therefore no fault.

The two payloads are `payload1.asm` (alphabet) and `payload2.asm` (digits). They are in their physical memory locations at startup, so they don't need to be moved there.

## Using this in your own code

This is a good template for expanding upon if you want to use 6o6 as part of a multitasking or multithreaded setup. You would want to change the portion of the harness that faults for page accesses beyond the first three, of course, as well as a similar change to the offset, and you would need a set of CPU states for every process or thread you intend to have running simultaneously. For threads, you would share the address space between execution contexts in the same process and thus need to adjust the harness accordingly, so having every execution context be independent processes may make your harness less complicated.

As written this harness assumes fixed blocks of RAM per process, thus only requiring addition to compute the physical address, but also limits you to that fixed number of slots. A dynamic system would probably require making the fetch into an subroutine instead of inlining it, or only making the simplest sorts of fetches with the inline fetch macros and calling out for others, due to the inherent complexity of managing memory allocations on the fly.

If you need more memory for your system overall, especially if you expect your tasks to each require a large address space, you might combine this one with the next example "Virtual Memory geoRAM" and run the guest code entirely from non-system memory.