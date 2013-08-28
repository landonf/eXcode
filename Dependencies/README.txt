This directory contains source and binary dependencies:

PLBlockIMP.framework
    Description:
      Provides generic utilities for generating and managing custom assembly trampolines,
      including an independent implementation of imp_implementationWithBlock().

    Version:
      PLBlockIMP 1.0-beta2 built from https://github.com/plausiblelabs/plblockimp

    License:
      MIT

    Modifications:
      None

FScript.framework
    Description:
      Provides an in-process REPL.

    Version:
      F-Script 20100614 downloaded from http://www.fscript.org/

    License:
      MIT

    Modifications:
      - The library install name was modified to use @rpath.
      - Minor changes were made to the headers to fix build warnings.
