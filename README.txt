= eXcode: A better Xcode 5. =

A collection of hacks, tweaks, and improvements for Xcode 4;
bringing back what we liked about Xcode 3, but better.

== Contributing (or, why are there no unit tests?) ==

This project intended to be fun. In cases where the choices are:
 1) Conservative
 2) Awesome (but still correct).

I've generally picked #2. This means that the code includes such gems as
custom assembly block trampolines (see the EXPatchMaster class) for
implementing runtime patches of Objective-C class and instance methods.

There are no unit tests, there are certainly bugs. The choice to unit test
is an explicit one; the idea is to save time and keep development both
fun and lightweight, while recognizing that this will lead to regressions
and bugs that would have been caught with tests.

The primary project goal is to provide useful additions to Xcode without
worrying about the sort of long-term production software maintenance concerns,
code correctness, quality, etc, that is involved in our more serious projects.

After all, this is a bunch of extensions and patches for private, binary-only
software. It can and will break at any time, probably in spectacular ways.
The target audience consists entirely of developers, and some assembly will
be required.
