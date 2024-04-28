# 6o6 Examples: Virtual Memory geoRAM

## What it is

This example runs on a Commodore 64 or Commodore 128 in 64 mode, using a geoRAM or geoRAM-compatible RAM expander with at least 64K. VICE and other C64 emulators can emulate this device.

It is a simplistic emulator of an [RC2014](https://rc2014.co.uk/)-like system, but [using a 6502 CPU](https://ancientcomputing.blogspot.com/2017/05/a-6502-cpu-for-rc2014-part-1.html). It presents a serial console and a system ROM containing a basic machine language monitor and Lee Davison's EhBASIC, with a little over 48K of RAM available. However, the entire addressing space of the guest system is stored within the geoRAM -- none of the C64's physical memory is used to store it.

This is a good template to consider if your use case is an expanded or virtual memory architecture where you need more memory than your host system can provide.

## License note

The system ROM in this version is [a prebuilt binary](https://github.com/ancientcomputing/rc2014/tree/master/rom/6502/monitor_ehbasic) made available by Ben Chong, using the 6551 ACIA version (though this example does not actually emulate one). It was not modified or altered in any way for this example.

This build of EhBASIC has been modified by Chong to limit automatic RAM sizing to 32K, contain explicit cold and warm entry points ($c100 and $c103 respectively), hardcode "BIOS" console calls (these are trapped), and add a `SYS` command that returns to the monitor. The monitor is based on Daryl Rictor's 5.1.1 lite monitor, but has been also modified to resemble the Z80 RC2014 monitor and to allow continuation from `BRK`.

There is no explicit license for this ROM image. It is believed to be freely redistributable for at least non-commercial purposes under the original terms for Lee Davison's EhBASIC, Daryl Rictor's 5.1.1 lite monitor, and [Ben Chong's additional changes](https://github.com/ancientcomputing/rc2014/tree/master/source/6502/monitor). It is not under the FFSL. You do not need to distribute it to use 6o6, though you will not be able to run this example as originally intended without it.

## Building and running

To build, type `make`. The object is called `vmgr.prg`. If a directory `../prg/` exists, it will also be copied to it. It is `LOAD`ed and `RUN` like a BASIC program.

When first started, the program will verify that a geoRAM is present and functions in an expected manner. It will then copy the ROM to geoRAM (the border will flash) and start the monitor.

There is separate documentation for [the built-in monitor](https://github.com/ancientcomputing/rc2014/blob/master/docs/mon_user_guide.txt) and [EhBASIC](http://www.6502.org/users/mycorner/6502/ehbasic/index.html). The monitor will display basic instructions if you enter `?`.

To enter EhBASIC from the monitor from a cold start, type `g c100` and enter the amount of free memory you wish to use. The highest amount you should enter is 49408 bytes, which yields 48127 bytes free (1K and one byte less). If you press RETURN without entering anything, EhBASIC will try to enumerate free memory itself; this takes about a minute in the emulator. Due to a hard limit in the source code it cannot enumerate more than 32K of RAM (31743 bytes free). To reenter EhBASIC and keep any program intact, type `g c103` from the monitor.

The emulator translates PETSCII to and from true ASCII for you. However, EhBASIC will only parse and respond to keywords IN CAPITAL LETTERS. Some prompts and displays are formatted for an 80-column display and will take up two screen lines.

The monitor is re-invoked if you type the `SYS` command or execute a `BRK` instruction (such as `POKE 4096,0:CALL 4096`). You can attempt to continue from the offending instruction by pressing C, or cancel out to the monitor by pressing ESC, which is mapped to F1.

The emulator also remaps illegal instructions into `BRK`-like conditions and also forwards them to the monitor (so `POKE 4096,2:CALL 4096` will not hang the machine; it will simply go back to the monitor as well). Writes to emulated ROM are ignored. If you need to reset the emulator, you can press Control-Shift-Commodore and the guest CPU will be soft-reset back to the monitor (if you do this at a monitor prompt, nothing happens).

There is currently no provision for uploading an Intel HEX dump. If you press `U` by accident in the monitor, simply press ESC (F1) to cancel. However, you can freely dump (everything including ROM) and edit (everything but ROM) memory at any address within the guest 64K addressing space. The memory map is very simple, with RAM from $0000 to $c0ff and ROM from $c100 to $ffff.

## Technical explanation

You should ensure you understand the other examples first.

The geoRAM presents a paged 256-byte memory window at $de00 with its control registers at $dffe and $dfff. It is organized into 16K banks, with the desired bank number written to $dfff and the desired 256-byte page within that bank written to $dffe. All access to the geoRAM's memory occurs through that window. No explicit steps are needed for writeback and a new active page can be selected at any time. (This is not the same as the Commodore REU, which uses DMA.) The emulator uses the first 64K of the geoRAM as a 1:1 mapping to guest memory. All guest memory, including zero page and stack, is kept in the geoRAM.

Almost all the unique action in this example is in the harness. The harness in `harness.asm` and `harness.def` drives the geoRAM directly, which is recommended for any hardware-assisted system like this one, starting with the high byte for the desired page. Since banks are 16K, virtual addresses below $4000 can be selected directly as "bank 0." Other addresses require bit-shifts and masks to select the correct bank and page. This computation is fairly quick but not without cost, so the result is cached to speed up contiguous fetches such as reading an instruction (the current page is kept in `curpage`). Writes to emulated ROM addresses at $c100 and up are simply ignored. This harness does not generate any faults and can run in faultless mode for a little extra speed. 

The kernel and other emulator facilities are in `vmgr.asm`. These facilities include testing the geoRAM, copying the ROM, handling character set translation using a lookup table, servicing the cursor and passing data in and out. Once the ROM has been copied over, the kernel does not otherwise manipulate the geoRAM. Five routines are trapped: initializing the ACIA (a no-op), input-and-wait, input-and-return, output a character and output a string (mostly used by the monitor). These are all dealt with in the same way as previous examples by manually checking the PC and branching. No memory-mapped I/O is provided. Illegal instructions (and potentially any other exception) are turned into `BRK`s by setting up the stack the same way as a `BRK` and entering the monitor ROM's IRQ handler. Because a fetch has occurred and the guest PC points after the illegal instruction, the kernel adjusts the PC before manually pushing itto match that of a `BRK` (PC+2).

## Using this in your own code

The most useful part of this example is the harness. If you use 6o6 with some other hardware-assist scheme, like an MMU or another bank of memory, you would change the portion that converts virtual addresses to geoRAM banks and pages.

The geoRAM only allows one page to be banked in at once, which leads to some thrashing after instructions that manipulate memory since they're rarely on the same page as the instruction that was just decoded. Configuring your hardware to bank in both the instruction page and the data page will be more efficient, and will (not coincidentally) look very much like a more modern CPU with separate I/D caches.