# Symbol collision: `seams_path_nframes` and `seams_last_error`

`libseams` (`include/seams.h`) and `libseams_lang`
(`bindings/cxx/seams_lang.h`) each export two C symbols of the same
name and a different type. At the seams-core tag `v2.14.1`
(`0f6c82810f5c1e61a70c363cca50fe8148b3ff21`) the declarations are:

| Symbol | `libseams` | `libseams_lang` |
|---|---|---|
| `seams_path_nframes` | `seams_status seams_path_nframes(const char *path, size_t *nframes)` | `int seams_path_nframes(const char *path)` |
| `seams_last_error` | `const char *seams_last_error(void)` | `const char *seams_last_error(void)` |

No other name is declared by both headers. `seams_last_error_message`
belongs only to `libseams`.

The two `seams_path_nframes` functions do not agree on a `.con` file.
The C API, when the engine is built with readcon-core, counts the
frames and writes that count through `nframes`, then returns
`SEAMS_OK` (`0`). The language function does not hand `.con` to
readcon. It returns `0`, which is a count, not a status. A call that
was compiled against the C API and bound to the language symbol
therefore sees a success code and leaves the caller's `size_t` at
whatever it was initialized to. `nframes()` on a one-frame `.con` file
comes back as `0`.

A dynamic loader binds one definition for the whole process. The R
package links `-lseams_lang` before `-lseams` (`configure`). That order
is required: `dseams.cpp` and `seams_lang.cpp` call the one-argument
form. Putting `-lseams` first would bind those calls to the
two-argument function, which writes through a second pointer the
caller did not pass. Swapping the link line is not a fix.

The bundled engine does not have the collision. `tools/vendor.sh`
compiles both translation units into one shared object and inserts

```c
#define seams_path_nframes seams_lang_path_nframes
#define seams_last_error seams_lang_last_error
```

into the copied `seams_lang.h`, so the language definitions are
emitted under the `seams_lang_` names. `configure.win` builds only
that copy (`SEAMS_STATIC` in `src/Makevars.win`).

A linked build cannot rename an already-built `libseams_lang`.
`src/seams_call.c` resolves `seams_path_nframes` from the object that
exports `seams_system_create` (the C symbol behind R's
`seams_system_new`; `libseams_lang` does not define it). On Linux and
macOS that is `dladdr` of the `RTLD_NEXT` address, then `dlopen` with
`RTLD_NOLOAD` and `dlsym`. On Windows the same lookup is
`GetModuleHandleEx` from the `dllimport` address and
`GetProcAddress`. The direct call stays in the `SEAMS_STATIC` build.
`dseams.cpp` still calls the language `seams_last_error`, and the C
API side uses `seams_last_error_message`, so this package does not
rebind `seams_last_error`.

## What seams-core can change

Rename the two language definitions, and the declarations in
`bindings/cxx/seams_lang.h`, to `seams_lang_path_nframes` and
`seams_lang_last_error`. Leave the `include/seams.h` names as they
are: those are the `SEAMS_ABI` 1 entries. The `seams_lang_` spellings
are what `tools/vendor.sh` already forces on the bundled copy, so a
seams-core change of that shape matches this package.

The language names are the C ABI shared by the Python, R, and Julia
fronts, so the rename is an ABI break for `libseams_lang` and needs a
coordinated bump. After it ships, a linked `dseams` can call
`seams_path_nframes` directly and drop the `dlopen` lookup, and
`tools/vendor.sh` can drop the two `#define` lines.

Symbol versions do not replace the rename. They are an ELF feature,
and the same pair of libraries is built for macOS and Windows.
