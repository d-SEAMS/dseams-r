// Copyright (c) d-SEAMS developers
#ifndef DSEAMS_R_IO_H_
#define DSEAMS_R_IO_H_

// Console output of the bundled engine. tools/vendor.sh rewrites the
// engine's std::cout, std::cerr, fprintf(stderr, ...) and std::exit to
// these, so that messages reach the R console and an engine failure
// becomes an R error instead of ending the session.

#include <cstddef>
#include <ostream>

namespace dseams_r {

std::ostream &out();
std::ostream &err();
int eprintf(const char *fmt, ...);
[[noreturn]] void fail(int status);

// The object size the checked sprintf wrappers pass to vsnprintf, and the
// check of its result. src/dseams.cpp reaches them for the tests.
std::size_t sprintf_capacity(std::size_t object_size);
int checked_sprintf(int size, std::size_t capacity);

} // namespace dseams_r

extern "C" int dseams_r_sprintf_chk(char *buf, int flags, std::size_t object_size,
                                    const char *fmt, ...);

#endif
