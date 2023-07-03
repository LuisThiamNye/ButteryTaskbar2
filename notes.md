
TODO (?) zone around the taskbar where it won't disappear if the mouse is present there.



:nullify_print_and_log_statements:
The program hooks into shell events runs constantly in the background,
so performance is critical. Thus, we replace the bodies of print and log
with nothing for the release build, and hopefully LLVM optimises the call sites away.

Other options considered
- Strip out the calls to log and print from the procedure bodies. This is more complicated as I think I would have to walk and modify a tree structure.
- Rename the original procedures and provide definitions that depend on a RELEASE_MODE constant to switch between the original and stub versions. Unfortunately, I do not believe this is possible since renamers are no longer a thing.
- Same as above, but just use a different name for the logging functions. Can easily scan the code for uses of the Basic log procedures and disallow them in the release build (and/or add a @note for exclusion).