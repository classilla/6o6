# 6o6 Testsuite

This is the 6o6 automated test suite. It is not required to use 6o6, but if you plan to submit changes, you must ensure that those changes pass these tests. To run the automated tests, you will need:

* A C compiler and `make`
* `xa` (which you would need to build 6o6 in the first place)
 
There are three component directories:

* `klaus_6502` contains Klaus Dormann's 6502 functional test suite, which is used as the primary test vector. It is directly downloaded from [the Github repository](https://github.com/Klaus2m5/6502_65C02_functional_tests). It is GPLv3. You are not required to distribute it to distribute 6o6, but you will not be able to use this testsuite without it.

* `lib6502` contains a modified version of [Ian Piumarta's `lib6502`](https://www.piumarta.com/software/lib6502/) emulator library. In addition to changing the compiler flags in the `Makefile`s, the patches that have been applied are provided for your reference: `dschmenk.patch`, David Schmenk's single stepper patch from [PLASMA](https://github.com/dschmenk/PLASMA/tree/master/src/lib6502); `decimal.patch`, a correctness fix I added for decimal mode; and `environ.patch`, which adds a new machine model and test harness into `run6502` expressly for running this controlled simulation. It is MIT licensed. You are not required to distribute it to distribute 6o6, but you will not be able to use this testsuite without it.

* `src` contains the 6502 assembly and include files to build the 6o6 harness and kernel to run Klaus' test suite (`ktest_h.asm` and `ktest_k.asm` respectively). It also contains a quick test to ensure that the modifications to `run6502` are working correctly (`checkenv.asm`). It is under FFSL, as is the main package.

The new machine model for `run6502` creates a bank-switched memory space large enough to hold the 64K test suite and 6o6 simultaneously. In this model memory between $7000 and $efff can be one of two 32K banks, switched in by writing to $0 or $1. `run6502` will automatically spread the suite over the banks during the loading process. The run loop is also modified to single step and, if the program counter loops on itself such as hitting an infinite loop branch or with a string of BRK instructions, to detect the situation as a failure state except at the fixed success address indicating the end of test. The guest can communicate success or failure to `lib6502` by reading from $0 (failure) or $1 (success), which will then terminate the test accordingly. The new machine model is enabled with the `-6` option to `run6502`, and the managed run loop is enabled with the `-L` option.

To run the test suite, ensure that `src/6o6.asm` is a symlink to `../6o6.asm` or to your modified version, and type `make` in this directory. This will then trigger the following steps:

* The modified `lib6502` will be compiled and linked.
* Because 6o6 uses the CPU's ALU for flags, the CPU's ALU must itself be correct, so `lib6502` will be directly tested against Klaus' test suite first. If this fails, there is a problem with `lib6502` on your system and all subsequent tests will be invalid.
* 6o6 will be assembled in "no extra helpings" using slow harness calls, "no extra helpings" with inline fetch macros and "always extra helpings" with inline fetch macros, and run against `checkenv.asm`, which will ensure that the machine model in `run6502` works properly. If this fails, check that any modifications to `lib6502` are correct, then verify 6o6.
* The same variations of 6o6 will then be run against Klaus' test suite. These tests may take up to several minutes on slower computers. If these fail, but previous tests passed, verify your changes to 6o6.

At the end of each run, the total number of instructions executed is displayed as an aid to optimization, as well as the current wall clock time.

The environment check 6o6 tests are run showing each tick of the emulated 6o6 PC by passing `run6502` the `-LL` option instead of `-L`. All other tests are run with no output other than success or failure messages. If you wish to see each emulated 6o6 instruction of the testsuite, change the corresponding test call in `src/Makefile` to `-LL`, though this will generate a fair bit of output. However, if you need to see each and every instruction as actually executed by `lib6502`, then pass the `-LLL` option instead (but this is even more incredibly spammy).

