/* Copyright (c) d-SEAMS developers */
/* .Call shim over include/seams.h. No C++ and no engine headers. */

/* dlopen's RTLD_NOLOAD and RTLD_NEXT are glibc extensions. macOS
 * declares them without this macro. The Windows package build defines
 * SEAMS_STATIC (src/Makevars.win, which configure.win fills) and does
 * not include this header. */
#ifndef SEAMS_STATIC
#ifndef _WIN32
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#endif
#endif

#include <limits.h>
#include <stdio.h>
#include <string.h>

#include <R.h>
#include <Rinternals.h>

#include "seams.h"

#ifndef SEAMS_STATIC
#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#else
#include <dlfcn.h>
#endif
#endif

static seams_system *sys_of(SEXP ext) {
  if (TYPEOF(ext) != EXTPTRSXP) {
    error("system handle");
  }
  seams_system *sys = (seams_system *)R_ExternalPtrAddr(ext);
  if (sys == NULL) {
    error("empty system");
  }
  return sys;
}

static void sys_fin(SEXP ext) {
  seams_system *sys = (seams_system *)R_ExternalPtrAddr(ext);
  if (sys != NULL) {
    seams_system_destroy(sys);
  }
  R_ClearExternalPtr(ext);
}

static void die(const void *handle) {
  const char *text = seams_handle_error(handle);
  error("%s", text == NULL ? "" : text);
}

static void copy_error(const void *handle, char *saved, size_t cap) {
  const char *text = seams_handle_error(handle);
  snprintf(saved, cap, "%s", text == NULL ? "" : text);
}

static SEXP real_n(R_xlen_t n) { return allocVector(REALSXP, n); }

SEXP seams_r_system(void) {
  seams_system *sys = seams_system_create();
  if (sys == NULL) {
    error("null system");
  }
  SEXP ext = PROTECT(R_MakeExternalPtr(sys, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(ext, sys_fin, TRUE);
  UNPROTECT(1);
  return ext;
}

SEXP seams_r_read(SEXP ext, SEXP path, SEXP frame, SEXP type) {
  seams_system *sys = sys_of(ext);
  const char *text = Rf_translateCharUTF8(STRING_ELT(path, 0));
  if (seams_system_read(sys, text, Rf_asInteger(frame), Rf_asInteger(type)) != SEAMS_OK) {
    die(sys);
  }
  return ScalarInteger(seams_system_count(sys));
}

SEXP seams_r_count(SEXP ext) { return ScalarInteger(seams_system_count(sys_of(ext))); }

/* libseams and libseams_lang both export seams_path_nframes.
 * libseams_lang's takes the path and returns a count, and that count
 * is 0 for a .con file, which the language counter does not hand to
 * readcon. libseams's writes the count through a size_t * and returns
 * SEAMS_OK, which is also 0. configure links -lseams_lang first, so
 * the reloc for the call below binds the language symbol: the 0 comes
 * back as success and the count stays 0. dseams.cpp and
 * seams_lang.cpp call the one-argument form on purpose, so the link
 * order has to stay. The bundled copy defines SEAMS_STATIC and
 * tools/vendor.sh renames the language symbol, so the direct call
 * there is libseams's. configure.win builds only that copy.
 *
 * seams_system_create is the C symbol behind R's seams_system_new. It
 * is exported by libseams and not by libseams_lang, so the object that
 * holds it is libseams. The address of the call from this file can be
 * this object's PLT stub, which names the wrong object; RTLD_NEXT
 * (and, on Windows, the import of the dllimport declaration) is the
 * address inside libseams. */
#ifndef SEAMS_STATIC
typedef seams_status (*seams_capi_path_nframes_fn)(const char *path, size_t *nframes);

static seams_capi_path_nframes_fn capi_path_nframes = NULL;

static int bind_fail(const char **message, const char *text) {
  if (message != NULL) {
    *message = text;
  }
  return -1;
}

static int bind_capi_path_nframes(const char **message) {
  if (capi_path_nframes != NULL) {
    return 0;
  }
#if defined(_WIN32)
  {
    HMODULE mod = NULL;
    FARPROC proc = NULL;
    union {
      seams_system *(*fn)(void);
      const char *addr;
    } pun;
    pun.fn = seams_system_create;
    if (pun.addr == NULL ||
        !GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                                GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                            pun.addr, &mod) ||
        mod == NULL) {
      return bind_fail(message, "could not locate the libseams that exports seams_system_create");
    }
    proc = GetProcAddress(mod, "seams_path_nframes");
    if (proc == NULL) {
      proc = GetProcAddress(mod, "_seams_path_nframes");
    }
    if (proc == NULL) {
      return bind_fail(message, "libseams does not export seams_path_nframes");
    }
    memcpy(&capi_path_nframes, &proc, sizeof(capi_path_nframes));
  }
#else
  {
    void *anchor = dlsym(RTLD_NEXT, "seams_system_create");
    void *handle = NULL;
    void *sym = NULL;
    Dl_info info;
    int flags = RTLD_LAZY | RTLD_LOCAL;
    if (anchor == NULL) {
      anchor = dlsym(RTLD_DEFAULT, "seams_system_create");
    }
    memset(&info, 0, sizeof(info));
    if (anchor == NULL || dladdr(anchor, &info) == 0 || info.dli_fname == NULL ||
        info.dli_fname[0] == '\0') {
      return bind_fail(message, "could not locate the libseams that exports seams_system_create");
    }
#ifdef RTLD_NOLOAD
    flags |= RTLD_NOLOAD;
#endif
#ifdef RTLD_FIRST
    flags |= RTLD_FIRST;
#endif
    handle = dlopen(info.dli_fname, flags);
    if (handle == NULL) {
      /* macOS refuses RTLD_NOLOAD when dli_fname is not the path the
       * image was loaded under. Opening that path maps the same file
       * the package already links, and dlclose drops the extra
       * reference below. */
      flags = RTLD_LAZY | RTLD_LOCAL;
#ifdef RTLD_FIRST
      flags |= RTLD_FIRST;
#endif
      handle = dlopen(info.dli_fname, flags);
    }
    if (handle == NULL) {
      return bind_fail(message, "could not open the libseams that exports seams_system_create");
    }
    sym = dlsym(handle, "seams_path_nframes");
    dlclose(handle);
    if (sym == NULL) {
      return bind_fail(message, "libseams does not export seams_path_nframes");
    }
    /* dlsym on a handle also searches that object's dependencies.
     * libseams defines this symbol itself; a hit in another object is
     * the language binding's one-argument function. */
    {
      Dl_info sym_info;
      memset(&sym_info, 0, sizeof(sym_info));
      if (dladdr(sym, &sym_info) == 0 || sym_info.dli_fbase != info.dli_fbase) {
        return bind_fail(message, "seams_path_nframes did not resolve inside libseams");
      }
    }
    memcpy(&capi_path_nframes, &sym, sizeof(capi_path_nframes));
  }
#endif
  if (capi_path_nframes == NULL) {
    return bind_fail(message, "could not resolve seams_path_nframes in libseams");
  }
  return 0;
}
#endif

/* Frame count through the C API. The language counter does not report
 * a readcon file. message receives the engine text and stays valid
 * until the next C API call on this thread. */
int seams_capi_nframes(const char *path, const char **message) {
  size_t n = 0;
  seams_status status;
  if (path == NULL) {
    if (message != NULL) {
      *message = "path is null";
    }
    return -1;
  }
#ifndef SEAMS_STATIC
  if (bind_capi_path_nframes(message) != 0) {
    return -1;
  }
  status = capi_path_nframes(path, &n);
#else
  status = seams_path_nframes(path, &n);
#endif
  if (status != SEAMS_OK) {
    if (message != NULL) {
      const char *text = seams_last_error_message();
      *message = (text == NULL || text[0] == '\0') ? "unreadable trajectory" : text;
    }
    return -1;
  }
  if (n > (size_t)INT_MAX) {
    if (message != NULL) {
      *message = "frame count does not fit in an integer";
    }
    return -1;
  }
  return (int)n;
}

SEXP seams_r_threads(SEXP n) {
  int threads = Rf_asInteger(n);
  if (seams_set_num_threads(threads) != SEAMS_OK) {
    error("%s", seams_last_error_message());
  }
  return ScalarInteger(seams_get_num_threads());
}

SEXP seams_r_chill(SEXP ext, SEXP cutoff, SEXP type, SEXP graph, SEXP rule) {
  seams_system *sys = sys_of(ext);
  const int n = seams_system_count(sys);
  SEXP labels = PROTECT(allocVector(INTSXP, n));
  SEXP counts = PROTECT(allocVector(INTSXP, 9));
  if (seams_chill(sys, Rf_asReal(cutoff), Rf_asInteger(type), Rf_asInteger(graph), Rf_asInteger(rule),
                  INTEGER(labels), (size_t)n, INTEGER(counts)) != SEAMS_OK) {
    die(sys);
  }
  UNPROTECT(2);
  return counts;
}

SEXP seams_r_steinhardt(SEXP ext, SEXP cutoff, SEXP order, SEXP average) {
  seams_system *sys = sys_of(ext);
  const int n = seams_system_count(sys);
  SEXP ql = PROTECT(real_n(n));
  SEXP bar = PROTECT(real_n(Rf_asInteger(average) ? n : 0));
  if (seams_steinhardt(sys, Rf_asReal(cutoff), 0, Rf_asInteger(order), REAL(ql), (size_t)n,
                       Rf_asInteger(average) ? REAL(bar) : NULL, (size_t)n) != SEAMS_OK) {
    die(sys);
  }
  SEXP out = PROTECT(allocVector(VECSXP, 2));
  SET_VECTOR_ELT(out, 0, ql);
  SET_VECTOR_ELT(out, 1, bar);
  UNPROTECT(3);
  return out;
}

SEXP seams_r_cages(SEXP ext, SEXP cutoff, SEXP graph, SEXP k, SEXP complete) {
  seams_system *sys = sys_of(ext);
  seams_cage_set *cages = NULL;
  if (seams_cages(sys, Rf_asReal(cutoff), 0, Rf_asInteger(graph), Rf_asInteger(k),
                  Rf_asInteger(complete), &cages) != SEAMS_OK) {
    die(sys);
  }
  int n_hex = 0, n_cubic = 0, n_water = 0, n_both = 0;
  const int code = seams_cages_counts(cages, &n_hex, &n_cubic, &n_water, &n_both);
  char saved[512];
  if (code != SEAMS_OK) {
    copy_error(cages, saved, sizeof(saved));
  }
  seams_cages_destroy(cages);
  if (code != SEAMS_OK) {
    error("%s", saved);
  }
  SEXP out = PROTECT(allocVector(INTSXP, 4));
  INTEGER(out)[0] = n_hex;
  INTEGER(out)[1] = n_cubic;
  INTEGER(out)[2] = n_water;
  INTEGER(out)[3] = n_both;
  UNPROTECT(1);
  return out;
}

SEXP seams_r_signature(SEXP ext, SEXP cutoff, SEXP graph, SEXP spec) {
  seams_system *sys = sys_of(ext);
  size_t n_cages = 0, n_atoms = 0;
  if (seams_signature_cages(sys, Rf_asReal(cutoff), 0, Rf_asInteger(graph),
                            Rf_translateCharUTF8(STRING_ELT(spec, 0)), &n_cages, &n_atoms) != SEAMS_OK) {
    die(sys);
  }
  SEXP out = PROTECT(allocVector(INTSXP, 2));
  INTEGER(out)[0] = (int)n_cages;
  INTEGER(out)[1] = (int)n_atoms;
  UNPROTECT(1);
  return out;
}

SEXP seams_r_knn(SEXP ext, SEXP k, SEXP cutoff, SEXP mutual) {
  seams_system *sys = sys_of(ext);
  seams_neighbours *nb = NULL;
  if (seams_neighbours_knn(sys, Rf_asInteger(k), Rf_asReal(cutoff), 0, Rf_asInteger(mutual), &nb) !=
      SEAMS_OK) {
    die(sys);
  }
  size_t n_offsets = 0, nnz = 0;
  const int code = seams_neighbours_copy(nb, NULL, 0, &n_offsets, NULL, 0, &nnz);
  char saved[512];
  if (code != SEAMS_OK) {
    copy_error(nb, saved, sizeof(saved));
  }
  seams_neighbours_destroy(nb);
  if (code != SEAMS_OK) {
    error("%s", saved);
  }
  return ScalarInteger((int)nnz);
}

SEXP seams_r_rdf(SEXP ext, SEXP rmax, SEXP bins) {
  seams_system *sys = sys_of(ext);
  size_t n_out = 0;
  double volume = 0.0;
  if (seams_rdf(sys, Rf_asReal(rmax), Rf_asInteger(bins), 0, 0, NULL, NULL, NULL, 0, &n_out,
                &volume) != SEAMS_OK) {
    die(sys);
  }
  SEXP radius = PROTECT(real_n((R_xlen_t)n_out));
  SEXP g = PROTECT(real_n((R_xlen_t)n_out));
  if (seams_rdf(sys, Rf_asReal(rmax), Rf_asInteger(bins), 0, 0, REAL(radius), REAL(g), NULL, n_out,
                &n_out, NULL) != SEAMS_OK) {
    die(sys);
  }
  SEXP vol = PROTECT(ScalarReal(volume));
  SEXP out = PROTECT(allocVector(VECSXP, 3));
  SET_VECTOR_ELT(out, 0, radius);
  SET_VECTOR_ELT(out, 1, g);
  SET_VECTOR_ELT(out, 2, vol);
  UNPROTECT(4);
  return out;
}

SEXP seams_r_running_cn(SEXP ext, SEXP rmax, SEXP bins) {
  seams_system *sys = sys_of(ext);
  size_t n_out = 0;
  if (seams_running_cn(sys, Rf_asReal(rmax), Rf_asInteger(bins), 0, 0, NULL, NULL, 0, &n_out) !=
      SEAMS_OK) {
    die(sys);
  }
  SEXP radius = PROTECT(real_n((R_xlen_t)n_out));
  SEXP cn = PROTECT(real_n((R_xlen_t)n_out));
  if (seams_running_cn(sys, Rf_asReal(rmax), Rf_asInteger(bins), 0, 0, REAL(radius), REAL(cn), n_out,
                       &n_out) != SEAMS_OK) {
    die(sys);
  }
  UNPROTECT(2);
  return cn;
}

SEXP seams_r_coordination(SEXP ext, SEXP rmax, SEXP bins) {
  seams_system *sys = sys_of(ext);
  double cn = 0.0;
  if (seams_coordination(sys, Rf_asReal(rmax), Rf_asInteger(bins), 0, 0, &cn) != SEAMS_OK) {
    die(sys);
  }
  return ScalarReal(cn);
}

SEXP seams_r_hbonds(SEXP ext, SEXP cutoff, SEXP oxygen, SEXP hydrogen, SEXP dist, SEXP angle) {
  seams_system *sys = sys_of(ext);
  int n_bonds = 0;
  if (seams_hbonds(sys, Rf_asReal(cutoff), Rf_asInteger(oxygen), Rf_asInteger(hydrogen),
                   Rf_asReal(dist), Rf_asReal(angle), &n_bonds) != SEAMS_OK) {
    die(sys);
  }
  return ScalarInteger(n_bonds);
}

SEXP seams_r_density(SEXP ext, SEXP type, SEXP bins, SEXP axis) {
  seams_system *sys = sys_of(ext);
  size_t n_out = 0;
  if (seams_density_axis(sys, Rf_asInteger(type), Rf_asInteger(bins), Rf_asInteger(axis), NULL, NULL,
                         0, &n_out) != SEAMS_OK) {
    die(sys);
  }
  SEXP z = PROTECT(real_n((R_xlen_t)n_out));
  SEXP rho = PROTECT(real_n((R_xlen_t)n_out));
  if (seams_density_axis(sys, Rf_asInteger(type), Rf_asInteger(bins), Rf_asInteger(axis), REAL(z),
                         REAL(rho), n_out, &n_out) != SEAMS_OK) {
    die(sys);
  }
  UNPROTECT(2);
  return rho;
}

SEXP seams_r_fingerprint(SEXP ext, SEXP cutoff, SEXP hops) {
  seams_system *sys = sys_of(ext);
  seams_topo *fp = NULL;
  if (seams_fingerprint(sys, Rf_asReal(cutoff), 0, 4, SEAMS_GRAPH_CUTOFF, Rf_asInteger(hops), 0,
                        &fp) != SEAMS_OK) {
    die(sys);
  }
  size_t n_out = 0;
  int counts[13] = {0};
  int code = seams_fingerprint_key(fp, NULL, 0, &n_out);
  if (code == SEAMS_OK) {
    code = seams_fingerprint_rings(fp, counts, 13);
  }
  char saved[512];
  if (code != SEAMS_OK) {
    copy_error(fp, saved, sizeof(saved));
  }
  seams_fingerprint_destroy(fp);
  if (code != SEAMS_OK) {
    error("%s", saved);
  }
  int ring_sum = 0;
  for (int i = 0; i < 13; ++i) {
    ring_sum += counts[i];
  }
  SEXP out = PROTECT(allocVector(INTSXP, 2));
  INTEGER(out)[0] = (int)n_out;
  INTEGER(out)[1] = ring_sum;
  UNPROTECT(1);
  return out;
}

SEXP seams_r_pairs(SEXP ext, SEXP spec) {
  seams_system *sys = sys_of(ext);
  size_t n_pairs = 0;
  int n_cation = 0, n_anion = 0;
  if (seams_contact_pairs(sys, Rf_translateCharUTF8(STRING_ELT(spec, 0)), &n_pairs, &n_cation,
                          &n_anion) != SEAMS_OK) {
    die(sys);
  }
  SEXP out = PROTECT(allocVector(INTSXP, 3));
  INTEGER(out)[0] = (int)n_pairs;
  INTEGER(out)[1] = n_cation;
  INTEGER(out)[2] = n_anion;
  UNPROTECT(1);
  return out;
}

SEXP seams_r_domains(SEXP ext, SEXP cutoff, SEXP spec, SEXP subset) {
  seams_system *sys = sys_of(ext);
  int n_subset = 0, largest = 0;
  double percolation = 0.0;
  if (seams_domains(sys, Rf_asReal(cutoff), Rf_translateCharUTF8(STRING_ELT(spec, 0)),
                    Rf_asInteger(subset), &n_subset, &largest, &percolation) != SEAMS_OK) {
    die(sys);
  }
  SEXP out = PROTECT(real_n(3));
  REAL(out)[0] = n_subset;
  REAL(out)[1] = largest;
  REAL(out)[2] = percolation;
  UNPROTECT(1);
  return out;
}

SEXP seams_r_prisms(SEXP ext, SEXP cutoff) {
  seams_system *sys = sys_of(ext);
  SEXP perfect = PROTECT(allocVector(INTSXP, 7));
  SEXP imperfect = PROTECT(allocVector(INTSXP, 7));
  if (seams_prisms(sys, Rf_asReal(cutoff), 0, INTEGER(perfect), INTEGER(imperfect), 7) != SEAMS_OK) {
    die(sys);
  }
  UNPROTECT(2);
  return perfect;
}

SEXP seams_r_monolayer(SEXP ext, SEXP cutoff, SEXP depth, SEXP area) {
  seams_system *sys = sys_of(ext);
  const int max_depth = Rf_asInteger(depth);
  SEXP counts = PROTECT(allocVector(INTSXP, max_depth + 1));
  if (seams_monolayer(sys, Rf_asReal(cutoff), 0, max_depth, Rf_asReal(area), INTEGER(counts),
                      (size_t)(max_depth + 1)) != SEAMS_OK) {
    die(sys);
  }
  UNPROTECT(1);
  return counts;
}

SEXP seams_r_vertices(SEXP ext, SEXP cutoff, SEXP depth, SEXP index) {
  seams_system *sys = sys_of(ext);
  seams_rings *rings = NULL;
  if (seams_rings_find(sys, Rf_asReal(cutoff), 0, SEAMS_GRAPH_CUTOFF, Rf_asInteger(depth), &rings) !=
      SEAMS_OK) {
    die(sys);
  }
  size_t n_out = 0;
  int code = seams_rings_vertices(rings, Rf_asInteger(index), NULL, 0, &n_out);
  SEXP atoms = PROTECT(allocVector(INTSXP, (R_xlen_t)n_out));
  if (code == SEAMS_OK) {
    code = seams_rings_vertices(rings, Rf_asInteger(index), INTEGER(atoms), n_out, &n_out);
  }
  char saved[512];
  if (code != SEAMS_OK) {
    copy_error(rings, saved, sizeof(saved));
  }
  seams_rings_destroy(rings);
  if (code != SEAMS_OK) {
    error("%s", saved);
  }
  UNPROTECT(1);
  return atoms;
}

SEXP seams_r_site(SEXP ext, SEXP spec) {
  seams_system *sys = sys_of(ext);
  const int n = seams_system_count(sys);
  SEXP kinds = PROTECT(allocVector(INTSXP, n));
  if (seams_site_table(sys, Rf_translateCharUTF8(STRING_ELT(spec, 0)), INTEGER(kinds), (size_t)n) !=
      SEAMS_OK) {
    die(sys);
  }
  UNPROTECT(1);
  return kinds;
}
