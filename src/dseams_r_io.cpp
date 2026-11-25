// Copyright (c) d-SEAMS developers
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include "dseams_r_io.h"

#include <climits>
#include <cstdarg>
#include <cstddef>
#include <cstdio>
#include <stdexcept>
#include <streambuf>
#include <string>
#include <thread>
#include <vector>

#include <R_ext/Error.h>
#include <R_ext/Print.h>

namespace dseams_r {
namespace {

// The library is loaded by dyn.load on R's main thread. R's printing API
// must not be called from any other thread, so text written by an engine
// worker thread is dropped.
const std::thread::id main_thread = std::this_thread::get_id();

bool on_main_thread() { return std::this_thread::get_id() == main_thread; }

void emit(const char *text, std::size_t n, bool to_err) {
  if (n == 0 || !on_main_thread()) {
    return;
  }
  const int len = static_cast<int>(n);
  if (to_err) {
    REprintf("%.*s", len, text);
  } else {
    Rprintf("%.*s", len, text);
  }
}

class ConsoleBuf : public std::streambuf {
public:
  explicit ConsoleBuf(bool to_err) : to_err_(to_err) {}

protected:
  int_type overflow(int_type ch) override {
    if (traits_type::eq_int_type(ch, traits_type::eof())) {
      return traits_type::not_eof(ch);
    }
    const char c = traits_type::to_char_type(ch);
    emit(&c, 1, to_err_);
    return ch;
  }

  std::streamsize xsputn(const char *s, std::streamsize n) override {
    emit(s, static_cast<std::size_t>(n), to_err_);
    return n;
  }

private:
  bool to_err_;
};

ConsoleBuf reader_cout_buf(false);
ConsoleBuf reader_cerr_buf(true);

} // namespace

// The bundled chemfiles archive refers to std::cout and std::cerr.
// tools/reader-symbols.sh renames those symbols onto these objects, which
// write to the R console. They are real iostreams, so the call sites keep
// the libstdc++ layout they were compiled against.
std::ostream dseams_r_cout_obj __asm__("dseams_r_cout")(&reader_cout_buf);
std::ostream dseams_r_cerr_obj __asm__("dseams_r_cerr")(&reader_cerr_buf);
std::ostream dseams_r_cout_libcxx __asm__("dseams_r_cout_libcxx")(&reader_cout_buf);
std::ostream dseams_r_cerr_libcxx __asm__("dseams_r_cerr_libcxx")(&reader_cerr_buf);

std::ostream &out() {
  thread_local ConsoleBuf buf(false);
  thread_local std::ostream stream(&buf);
  return stream;
}

std::ostream &err() {
  thread_local ConsoleBuf buf(true);
  thread_local std::ostream stream(&buf);
  return stream;
}

int eprintf(const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  va_list again;
  va_copy(again, args);
  const int n = std::vsnprintf(nullptr, 0, fmt, args);
  va_end(args);
  if (n > 0) {
    std::vector<char> text(static_cast<std::size_t>(n) + 1);
    std::vsnprintf(text.data(), text.size(), fmt, again);
    emit(text.data(), static_cast<std::size_t>(n), true);
  }
  va_end(again);
  return n;
}

void fail(int status) {
  throw std::runtime_error("d-SEAMS engine stopped with status " +
                           std::to_string(status));
}

} // namespace dseams_r

// Symbols Writing R Extensions rejects. reader-symbols.sh points the
// readcon-core and chemfiles archives here, so the shared library does
// not call abort, exit, or the C stdio console, and does not refer to
// stdout or stderr. None of these wrappers call the replaced symbol.
namespace {

ssize_t console_write(void *cookie, const char *buf, size_t n) {
  if (n == 0 || buf == nullptr) {
    return 0;
  }
  const int len = static_cast<int>(n);
  if (cookie != nullptr) {
    REprintf("%.*s", len, buf);
  } else {
    Rprintf("%.*s", len, buf);
  }
  return static_cast<ssize_t>(n);
}

FILE *open_console(bool to_err) {
#if defined(__GLIBC__)
  cookie_io_functions_t fns = {};
  fns.write = console_write;
  FILE *file = fopencookie(to_err ? reinterpret_cast<void *>(1) : nullptr, "w", fns);
  if (file != nullptr) {
    setvbuf(file, nullptr, _IONBF, 0);
  }
  return file;
#elif defined(__APPLE__)
  return funopen(
      to_err ? reinterpret_cast<void *>(1) : nullptr, nullptr,
      [](void *cookie, const char *buf, int n) -> int {
        return static_cast<int>(
            console_write(cookie, buf, static_cast<std::size_t>(n)));
      },
      nullptr, nullptr);
#else
  (void)to_err;
#if defined(_WIN32)
  return std::fopen("NUL", "w");
#else
  return std::fopen("/dev/null", "w");
#endif
#endif
}

} // namespace

extern "C" {
FILE *dseams_r_stdout;
FILE *dseams_r_stderr;
}

namespace {

__attribute__((constructor(101))) void init_reader_consoles() {
  dseams_r_stdout = open_console(false);
  dseams_r_stderr = open_console(true);
}

} // namespace

namespace dseams_r {

// Darwin's __sprintf_chk and __vsprintf_chk pass (size_t)-1 when the
// compiler does not know the size of the destination. vsnprintf fails
// with EOVERFLOW and writes nothing for a size above INT_MAX, so the size
// is clamped first.
std::size_t sprintf_capacity(std::size_t object_size) {
  const std::size_t limit = static_cast<std::size_t>(INT_MAX);
  return object_size > limit ? limit : object_size;
}

// A negative count is a vsnprintf failure, and the buffer holds nothing
// usable. A count of capacity or more means the text was cut.
int checked_sprintf(int size, std::size_t capacity) {
  if (size < 0) {
    Rf_error("bundled reader output could not be formatted");
  }
  if (static_cast<std::size_t>(size) >= capacity) {
    Rf_error("bundled reader output exceeds its buffer");
  }
  return size;
}

} // namespace dseams_r

extern "C" {

__attribute__((noreturn)) void dseams_r_abort(void) {
  Rf_error("bundled reader aborted");
}

__attribute__((noreturn)) void dseams_r_assert_rtn(
    const char *function, const char *file, int line, const char *expression) {
  Rf_error("bundled reader assertion failed in %s at %s:%d: %s", function,
           file, line, expression);
}

__attribute__((noreturn)) void dseams_r_exit(int status) {
  Rf_error("bundled reader exited with status %d", status);
}

__attribute__((noreturn)) void dseams_r__exit(int status) {
  Rf_error("bundled reader exited with status %d", status);
}

__attribute__((noreturn)) void dseams_r__Exit(int status) {
  Rf_error("bundled reader exited with status %d", status);
}

// The printf-family wrappers below return 0. They report that the text
// was handed to R, not how many characters R printed.
int dseams_r_printf(const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  Rvprintf(fmt, args);
  va_end(args);
  return 0;
}

int dseams_r_vprintf(const char *fmt, va_list args) {
  Rvprintf(fmt, args);
  return 0;
}

int dseams_r_vprintf_chk(int, const char *fmt, va_list args) {
  return dseams_r_vprintf(fmt, args);
}

int dseams_r_puts(const char *text) {
  if (text != nullptr) {
    Rprintf("%s\n", text);
  }
  return 0;
}

int dseams_r_putchar(int ch) {
  Rprintf("%c", ch);
  return ch;
}

int dseams_r_sprintf(char *buf, const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  const int n = std::vsnprintf(buf, 4096, fmt, args);
  va_end(args);
  return n;
}

int dseams_r_vsprintf(char *buf, const char *fmt, va_list args) {
  // The only caller is zlib's gzprintf fallback, which already has a
  // caller-sized buffer. Cap the write; vsnprintf is not a checked symbol.
  return std::vsnprintf(buf, 4096, fmt, args);
}

int dseams_r_printf_chk(int, const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  Rvprintf(fmt, args);
  va_end(args);
  return 0;
}

int dseams_r_vsprintf_chk(char *buf, int, size_t object_size, const char *fmt,
                         va_list args) {
  const size_t capacity = dseams_r::sprintf_capacity(object_size);
  return dseams_r::checked_sprintf(std::vsnprintf(buf, capacity, fmt, args),
                                   capacity);
}

int dseams_r_sprintf_chk(char *buf, int flags, size_t object_size,
                        const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  const int size = dseams_r_vsprintf_chk(buf, flags, object_size, fmt, args);
  va_end(args);
  return size;
}

#if defined(_WIN32)
// idx 1 and 2 are the UCRT stdout and stderr. idx 0 is stdin, and any
// other index is another CRT stream. Those go to the real
// __acrt_iob_func. This call sits in an object reader-symbols.sh does
// not rewrite, so it still resolves to the CRT import.
FILE *dseams_r___acrt_iob_func(unsigned idx) {
  if (idx == 1U) {
    return dseams_r_stdout;
  }
  if (idx == 2U) {
    return dseams_r_stderr;
  }
  return __acrt_iob_func(idx);
}

// mingw-w64 dllimport references the import slot, not the function.
FILE *(*dseams_r___imp___acrt_iob_func)(unsigned) = dseams_r___acrt_iob_func;
#endif

} // extern "C"
