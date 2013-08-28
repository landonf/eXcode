= eXcode: A better Xcode 5. =

A collection of hacks, tweaks, and improvements for serious engineers that are
seriously frustrated with the direction Xcode has taken.

== Contributing (or, why are there no unit tests?) ==

Unlike just about every project I've ever released, this project
is one gigantic hack. It's intended to be fun, and in cases where
the choices are 1) awesome, or 2) conservative, I've generally picked #1.

There are no unit tests, there are certainly bugs, in the choice between maintainable
and easy, we usually choose easy (as long as it's mostly correct). The main goal is to
provide some useful additions to Xcode without worrying about the sort of long-term
production software maintenance concerns, code correctness, quality, etc, that is involved
in our more serious projects.

After all, this is a bunch of runtime patches for private, binary-only software. It can
and will break at any time, probably in spectacular ways.