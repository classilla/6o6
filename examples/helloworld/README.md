# 6o6 Examples: Hello, World

## What it is

This example runs on an unmodified Commodore 64 or Commodore 128 in 64 mode, or on an Apple IIe, IIc or IIgs with at least 64K of memory.

It prints "hello world" to the screen and then terminates. Isn't that great? But it's 6o6 that's doing the work. _That's_ what's great.

This is a good template to consider if your use case is 6o6 running a single task in a controlled environment.

## Building and running

To build the C64 version, type `make c64`. The object is called `hello.prg`. If a directory `../prg/` exists, it will also be copied to it. It is `LOAD`ed and `RUN` like a BASIC program. You can run the program again afterwards.

To build the Apple II version, type `make a2`. The object is called `hello.b`. If [Apple Commander](https://applecommander.github.io/)'s `ac.jar` is in the same directory (a symlink or a copy), a DOS 3.3 disk image called `incept.do` will be generated with the binary. It should be `BRUN` like a binary program (or `BLOAD` and `CALL 2051`). You can run the program again afterwards with `CALL 2051`.

## Technical explanation

The two files `c64.def` and `a2.def` contain the 6o6 return codes, zero page labels and most of the configuration defines for the C64 and Apple II respectively. They also define the locations of the kernel (by default $0a00), harness ($0b00), VM ($0c00), and the start of emulated RAM ($3600). This is the physical address where guest memory starts. Within guest memory, the stack and zero page are in their usual locations. The payload is physically located at the start of emulated RAM plus $0200 (i.e., $3800, skipping stack and zero page), but within guest memory the payload is actually virtually mapped to $0a00, not $0200, the same as the kernel.

Therefore, computing the effective physical address from a virtual address is just addition; only the offset may differ. The harness is in `harness.asm`, with inline fetch macro versions in `harness.def`. For the stack and zero page ($0000-$01ff), we simply add the start of emulated RAM to get the physical address, though fetches from zero page can use the much faster two-instruction inline macro. For anything from the kernel-payload address on up ($0a00-), we add that address minus the kernel's, minus one for carry. If the computed physical address wraps or hits the I/O range, the harness will throw an exception. Note that this harness therefore has aliased memory for locations $0200 through $09ff, and does not present a full 64K range. Your applications aren't obligated to do so either and this is not an intrinsic limitation of 6o6. Also note that the harness can throw stack underflow and overflow exceptions on pulls and pushes.

The actual payload is stored in `payload.asm`. It can be run natively or from 6o6. It simply prints a string by repeatedly calling the ROM routine to emit a character (this is specified in the configuration file for the appropriate machine). The current version is limited to 256 bytes, but only because of the way this example copies it (see the main program below); it is also not an intrinsic limitation of 6o6. Notice that it is assembled with the same starting address as the kernel even though it is actually held in a different part of memory - that's because we've deliberately engineered the code such that it can substitute for it.

The kernel is stored in `kernel.asm`. It starts off by setting the guest PC to the virtual address of the payload and resetting the P and S registers, leaving nothing on the stack, then calling the VM. If the VM returns success, it will see if the PC is now pointing to the character output routine. If it is, it grabs the guest accumulator and calls the ROM routine on its behalf, then (assuming no underflow) goes back for the next instruction or instruction group. If it isn't, it proceeds to the next instruction or instruction group.

If an exception other than a stack underflow is raised, then the kernel will halt and wait for assistance (on the C64 it will show a colour pattern in the border corresponding to the return code). If a stack underflow is raised, then the kernel will assume the payload executed an `RTS` with nothing on the stack, and exit itself.

Finally, the main program is in `hello.asm`, which links together the other objects. It starts with its code, then the kernel (at $0900, offset $0100 bytes lower than where it would normally reside), a copy of the payload (at $0a00), the harness, the VM, and a second copy of the payload at $3800, sitting above the emulated RAM boundary. The main program first runs the payload natively. It then swaps the kernel and the first copy and runs the kernel, which executes the payload in emulated RAM. It then swaps them back so you can run it again, and terminates.

## Using this in your own code

This is a good template for simply running a single task under 6o6, such as running untrustworthy code in a sandbox, etc. You can intercept and emulate additional ROM routines in the kernel by adding more addresses, or creating a lookup and dispatch table.

To reduce complexity, you may want to make the memory map "flat" by simply adding `EMURAM` (i.e., the constant offset for the bottom of guest memory) for all addresses instead of a different constant for virtual addresses $0a00 and up. You can also make the harness synthesize a full 64K addressing space by returning a hardwired constant (usually $00 or $ff) for virtual addresses above your maximum RAM threshold, and simply ignoring writes to those addresses.