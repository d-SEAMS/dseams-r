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

SEXP seams_r_nframes(SEXP path) {
  const char *text = Rf_translateCharUTF8(STRING_ELT(path, 0));
  const char *message = NULL;
  int n = seams_capi_nframes(text, &message);
  if (n < 0) {
    error("%s", message == NULL ? "unreadable trajectory" : message);
  }
  return ScalarInteger(n);
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

SEXP seams_r_capi_info(void) {
  SEXP out = PROTECT(allocVector(VECSXP, 6));
  SET_VECTOR_ELT(out, 0, ScalarInteger(seams_abi()));
  SET_VECTOR_ELT(out, 1, ScalarInteger(seams_version()));
  SET_VECTOR_ELT(out, 2, ScalarInteger(seams_version_major()));
  SET_VECTOR_ELT(out, 3, ScalarInteger(seams_version_minor()));
  SET_VECTOR_ELT(out, 4, ScalarInteger(seams_version_patch()));
  SET_VECTOR_ELT(out, 5, mkString(seams_version_string()));
  UNPROTECT(1);
  return out;
}

SEXP seams_r_label_name(SEXP label) {
  return mkString(seams_label_name(Rf_asInteger(label)));
}

SEXP seams_r_ring_symmetry_name(SEXP sym) {
  return mkString(seams_ring_symmetry_name(Rf_asInteger(sym)));
}

SEXP seams_r_set_atoms(SEXP ext, SEXP xyz, SEXP box, SEXP types, SEXP ids) {
  seams_system *sys = sys_of(ext);
  SEXP dim = getAttrib(xyz, R_DimSymbol);
  if (TYPEOF(dim) != INTSXP || LENGTH(dim) != 2 || INTEGER(dim)[1] != 3) {
    error("xyz must be an n x 3 numeric matrix");
  }
  const int n = INTEGER(dim)[0];
  if (TYPEOF(xyz) != REALSXP) {
    error("xyz must be numeric");
  }
  if (TYPEOF(box) != REALSXP) {
    error("box must be numeric");
  }
  const int *types_ptr = NULL;
  if (!isNull(types)) {
    if (TYPEOF(types) != INTSXP || LENGTH(types) != n) {
      error("types must be an integer vector of length n");
    }
    types_ptr = INTEGER(types);
  }
  const int *ids_ptr = NULL;
  if (!isNull(ids)) {
    if (TYPEOF(ids) != INTSXP || LENGTH(ids) != n) {
      error("ids must be an integer vector of length n");
    }
    ids_ptr = INTEGER(ids);
  }
  const size_t n_atoms = (size_t)(n > 0 ? n : 0);
  double *packed = (double *)calloc(n_atoms > 0 ? n_atoms * 3 : 1, sizeof(double));
  if (packed == NULL) {
    error("out of memory");
  }
  const double *src = REAL(xyz);
  for (int i = 0; i < n; ++i) {
    packed[3 * (size_t)i + 0] = src[i];
    packed[3 * (size_t)i + 1] = src[i + n];
    packed[3 * (size_t)i + 2] = src[i + 2 * n];
  }
  const int code = seams_system_set_atoms(sys, packed, n_atoms, REAL(box),
                                          (size_t)LENGTH(box), types_ptr, ids_ptr);
  free(packed);
  if (code != SEAMS_OK) {
    die(sys);
  }
  return ScalarInteger(n);
}

SEXP seams_r_box(SEXP ext) {
  seams_system *sys = sys_of(ext);
  SEXP out = PROTECT(real_n(9));
  if (seams_system_box(sys, REAL(out), 9) != SEAMS_OK) {
    die(sys);
  }
  UNPROTECT(1);
  return out;
}

SEXP seams_r_positions(SEXP ext) {
  seams_system *sys = sys_of(ext);
  size_t n = 0;
  if (seams_system_natoms(sys, &n) != SEAMS_OK) {
    die(sys);
  }
  double *buf = (double *)calloc(n > 0 ? n * 3 : 1, sizeof(double));
  if (buf == NULL) {
    error("out of memory");
  }
  if (n > 0 && seams_system_positions(sys, buf, n * 3) != SEAMS_OK) {
    free(buf);
    die(sys);
  }
  SEXP mat = PROTECT(allocMatrix(REALSXP, (int)n, 3));
  double *dst = REAL(mat);
  for (size_t i = 0; i < n; ++i) {
    dst[i] = buf[3 * i + 0];
    dst[i + n] = buf[3 * i + 1];
    dst[i + 2 * n] = buf[3 * i + 2];
  }
  free(buf);
  UNPROTECT(1);
  return mat;
}

SEXP seams_r_types(SEXP ext) {
  seams_system *sys = sys_of(ext);
  size_t n = 0;
  if (seams_system_natoms(sys, &n) != SEAMS_OK) {
    die(sys);
  }
  SEXP out = PROTECT(allocVector(INTSXP, (R_xlen_t)n));
  if (n > 0 && seams_system_types(sys, INTEGER(out), n) != SEAMS_OK) {
    die(sys);
  }
  UNPROTECT(1);
  return out;
}

SEXP seams_r_ids(SEXP ext) {
  seams_system *sys = sys_of(ext);
  size_t n = 0;
  if (seams_system_natoms(sys, &n) != SEAMS_OK) {
    die(sys);
  }
  SEXP out = PROTECT(allocVector(INTSXP, (R_xlen_t)n));
  if (n > 0 && seams_system_ids(sys, INTEGER(out), n) != SEAMS_OK) {
    die(sys);
  }
  UNPROTECT(1);
  return out;
}

SEXP seams_r_system_symmetry(SEXP ext, SEXP shell_rmsd) {
  seams_system *sys = sys_of(ext);
  size_t n = 0;
  if (seams_system_natoms(sys, &n) != SEAMS_OK) {
    die(sys);
  }
  SEXP out = PROTECT(allocVector(INTSXP, (R_xlen_t)n));
  if (seams_system_symmetry(sys, Rf_asReal(shell_rmsd), INTEGER(out), n) != SEAMS_OK) {
    die(sys);
  }
  UNPROTECT(1);
  return out;
}

SEXP seams_r_q4q6(SEXP ext, SEXP cutoff, SEXP type) {
  seams_system *sys = sys_of(ext);
  size_t n = 0;
  if (seams_system_natoms(sys, &n) != SEAMS_OK) {
    die(sys);
  }
  SEXP q4 = PROTECT(real_n((R_xlen_t)n));
  SEXP q6 = PROTECT(real_n((R_xlen_t)n));
  if (seams_q4q6_n(sys, Rf_asReal(cutoff), Rf_asInteger(type),
                   REAL(q4), n, REAL(q6), n) != SEAMS_OK) {
    die(sys);
  }
  SEXP out = PROTECT(allocVector(VECSXP, 2));
  SET_VECTOR_ELT(out, 0, q4);
  SET_VECTOR_ELT(out, 1, q6);
  UNPROTECT(3);
  return out;
}

SEXP seams_r_q6bar(SEXP ext, SEXP cutoff, SEXP type, SEXP ice_cut) {
  seams_system *sys = sys_of(ext);
  size_t n = 0;
  if (seams_system_natoms(sys, &n) != SEAMS_OK) {
    die(sys);
  }
  SEXP q6bar = PROTECT(real_n((R_xlen_t)n));
  double mean = 0.0, median = 0.0;
  int n_ice = 0;
  if (seams_q6bar(sys, Rf_asReal(cutoff), Rf_asInteger(type), Rf_asReal(ice_cut),
                  REAL(q6bar), n, &mean, &median, &n_ice) != SEAMS_OK) {
    die(sys);
  }
  SEXP out = PROTECT(allocVector(VECSXP, 4));
  SET_VECTOR_ELT(out, 0, q6bar);
  SET_VECTOR_ELT(out, 1, ScalarReal(mean));
  SET_VECTOR_ELT(out, 2, ScalarReal(median));
  SET_VECTOR_ELT(out, 3, ScalarInteger(n_ice));
  UNPROTECT(2);
  return out;
}

SEXP seams_r_ql(SEXP ext, SEXP cutoff, SEXP type, SEXP order, SEXP graph) {
  seams_system *sys = sys_of(ext);
  size_t n = 0;
  if (seams_system_natoms(sys, &n) != SEAMS_OK) {
    die(sys);
  }
  SEXP ql = PROTECT(real_n((R_xlen_t)n));
  SEXP qlbar = PROTECT(real_n((R_xlen_t)n));
  if (seams_ql(sys, Rf_asReal(cutoff), Rf_asInteger(type), Rf_asInteger(order),
               Rf_asInteger(graph), REAL(ql), n, REAL(qlbar), n) != SEAMS_OK) {
    die(sys);
  }
  SEXP out = PROTECT(allocVector(VECSXP, 2));
  SET_VECTOR_ELT(out, 0, ql);
  SET_VECTOR_ELT(out, 1, qlbar);
  UNPROTECT(3);
  return out;
}

SEXP seams_r_cages_labels(SEXP ext, SEXP cutoff, SEXP type, SEXP graph, SEXP k, SEXP complete) {
  seams_system *sys = sys_of(ext);
  size_t n = 0;
  if (seams_system_natoms(sys, &n) != SEAMS_OK) {
    die(sys);
  }
  seams_cage_set *cages = NULL;
  if (seams_cages(sys, Rf_asReal(cutoff), Rf_asInteger(type), Rf_asInteger(graph),
                  Rf_asInteger(k), Rf_asInteger(complete), &cages) != SEAMS_OK) {
    die(sys);
  }
  SEXP labels = PROTECT(allocVector(INTSXP, (R_xlen_t)n));
  int n_hex = 0, n_cubic = 0, n_water = 0, n_both = 0;
  int code = seams_cages_labels(cages, INTEGER(labels), n);
  if (code == SEAMS_OK) {
    code = seams_cages_counts(cages, &n_hex, &n_cubic, &n_water, &n_both);
  }
  char saved[512];
  if (code != SEAMS_OK) {
    copy_error(cages, saved, sizeof(saved));
  }
  seams_cages_destroy(cages);
  if (code != SEAMS_OK) {
    error("%s", saved);
  }
  SEXP counts = PROTECT(allocVector(INTSXP, 4));
  INTEGER(counts)[0] = n_hex;
  INTEGER(counts)[1] = n_cubic;
  INTEGER(counts)[2] = n_water;
  INTEGER(counts)[3] = n_both;
  SEXP out = PROTECT(allocVector(VECSXP, 2));
  SET_VECTOR_ELT(out, 0, labels);
  SET_VECTOR_ELT(out, 1, counts);
  UNPROTECT(3);
  return out;
}

SEXP seams_r_signature_edge(SEXP ext, SEXP cutoff, SEXP type, SEXP graph, SEXP spec, SEXP edge) {
  seams_system *sys = sys_of(ext);
  size_t n_cages = 0, n_atoms = 0;
  if (seams_signature_cages_edge(sys, Rf_asReal(cutoff), Rf_asInteger(type), Rf_asInteger(graph),
                                 Rf_translateCharUTF8(STRING_ELT(spec, 0)),
                                 Rf_translateCharUTF8(STRING_ELT(edge, 0)),
                                 &n_cages, &n_atoms) != SEAMS_OK) {
    die(sys);
  }
  SEXP out = PROTECT(allocVector(INTSXP, 2));
  INTEGER(out)[0] = (int)n_cages;
  INTEGER(out)[1] = (int)n_atoms;
  UNPROTECT(1);
  return out;
}

SEXP seams_r_neighbours(SEXP ext, SEXP cutoff, SEXP type, SEXP graph) {
  seams_system *sys = sys_of(ext);
  seams_neighbours *nb = NULL;
  if (seams_neighbours_build(sys, Rf_asReal(cutoff), Rf_asInteger(type),
                             Rf_asInteger(graph), &nb) != SEAMS_OK) {
    die(sys);
  }
  size_t nrows = 0, n_off = 0, nnz = 0;
  int code = seams_neighbours_nrows(nb, &nrows);
  if (code == SEAMS_OK) {
    code = seams_neighbours_copy(nb, NULL, 0, &n_off, NULL, 0, &nnz);
  }
  SEXP offsets = PROTECT(allocVector(INTSXP, (R_xlen_t)n_off));
  SEXP cols = PROTECT(allocVector(INTSXP, (R_xlen_t)nnz));
  int dummy = 0;
  if (code == SEAMS_OK) {
    code = seams_neighbours_copy(
      nb,
      n_off > 0 ? INTEGER(offsets) : &dummy, n_off, &n_off,
      nnz > 0 ? INTEGER(cols) : &dummy, nnz, &nnz
    );
  }
  char saved[512];
  if (code != SEAMS_OK) {
    copy_error(nb, saved, sizeof(saved));
  }
  seams_neighbours_destroy(nb);
  if (code != SEAMS_OK) {
    error("%s", saved);
  }
  SEXP out = PROTECT(allocVector(VECSXP, 3));
  SET_VECTOR_ELT(out, 0, offsets);
  SET_VECTOR_ELT(out, 1, cols);
  SET_VECTOR_ELT(out, 2, ScalarInteger((int)nrows));
  UNPROTECT(3);
  return out;
}

SEXP seams_r_rings(SEXP ext, SEXP cutoff, SEXP type, SEXP graph, SEXP max_depth) {
  seams_system *sys = sys_of(ext);
  const int depth = Rf_asInteger(max_depth);
  if (depth < 0) {
    error("max_depth must be non-negative");
  }
  seams_rings *rings = NULL;
  if (seams_rings_find(sys, Rf_asReal(cutoff), Rf_asInteger(type),
                       Rf_asInteger(graph), depth, &rings) != SEAMS_OK) {
    die(sys);
  }
  size_t n_rings = 0;
  double frac = 0.0;
  int code = seams_rings_nrings(rings, &n_rings);
  if (code == SEAMS_OK) {
    code = seams_rings_fraction(rings, 0, &frac);
  }
  SEXP hist = PROTECT(allocVector(INTSXP, depth + 1));
  if (code == SEAMS_OK) {
    code = seams_rings_histogram_n(rings, INTEGER(hist), (size_t)(depth + 1));
  }
  SEXP sizes = PROTECT(allocVector(INTSXP, (R_xlen_t)n_rings));
  SEXP sym = PROTECT(allocVector(INTSXP, (R_xlen_t)n_rings));
  if (code == SEAMS_OK && n_rings > 0) {
    code = seams_rings_labels_n(rings, INTEGER(sizes), n_rings, INTEGER(sym), n_rings);
  }
  char saved[512];
  if (code != SEAMS_OK) {
    copy_error(rings, saved, sizeof(saved));
  }
  seams_rings_destroy(rings);
  if (code != SEAMS_OK) {
    error("%s", saved);
  }
  SEXP out = PROTECT(allocVector(VECSXP, 5));
  SET_VECTOR_ELT(out, 0, ScalarInteger((int)n_rings));
  SET_VECTOR_ELT(out, 1, hist);
  SET_VECTOR_ELT(out, 2, sizes);
  SET_VECTOR_ELT(out, 3, sym);
  SET_VECTOR_ELT(out, 4, ScalarReal(frac));
  UNPROTECT(4);
  return out;
}

SEXP seams_r_rings_chordless(SEXP ext, SEXP cutoff, SEXP type, SEXP graph, SEXP size) {
  seams_system *sys = sys_of(ext);
  const int rsize = Rf_asInteger(size);
  seams_neighbours *nb = NULL;
  if (seams_neighbours_build(sys, Rf_asReal(cutoff), Rf_asInteger(type),
                             Rf_asInteger(graph), &nb) != SEAMS_OK) {
    die(sys);
  }
  size_t nrows = 0, n_rings = 0;
  int dummy = 0;
  int code = seams_neighbours_nrows(nb, &nrows);
  SEXP per_atom = PROTECT(allocVector(INTSXP, (R_xlen_t)nrows));
  if (code == SEAMS_OK) {
    code = seams_rings_chordless(nb, rsize, NULL, 0, &n_rings,
                                 nrows > 0 ? INTEGER(per_atom) : &dummy, nrows);
  }
  SEXP mat = PROTECT(allocMatrix(INTSXP, (int)n_rings, rsize > 0 ? rsize : 1));
  if (code == SEAMS_OK && n_rings > 0) {
    int *buf = (int *)calloc(n_rings * (size_t)rsize, sizeof(int));
    if (buf == NULL) {
      seams_neighbours_destroy(nb);
      error("out of memory");
    }
    code = seams_rings_chordless(nb, rsize, buf, n_rings * (size_t)rsize, &n_rings, NULL, 0);
    if (code == SEAMS_OK) {
      int *dst = INTEGER(mat);
      for (size_t r = 0; r < n_rings; ++r) {
        for (int c = 0; c < rsize; ++c) {
          dst[r + (size_t)c * n_rings] = buf[r * (size_t)rsize + (size_t)c];
        }
      }
    }
    free(buf);
  }
  char saved[512];
  if (code != SEAMS_OK) {
    copy_error(nb, saved, sizeof(saved));
  }
  seams_neighbours_destroy(nb);
  if (code != SEAMS_OK) {
    error("%s", saved);
  }
  SEXP out = PROTECT(allocVector(VECSXP, 3));
  SET_VECTOR_ELT(out, 0, ScalarInteger((int)n_rings));
  SET_VECTOR_ELT(out, 1, mat);
  SET_VECTOR_ELT(out, 2, per_atom);
  UNPROTECT(3);
  return out;
}

SEXP seams_r_fingerprint_atoms(SEXP ext, SEXP cutoff, SEXP type, SEXP k,
                               SEXP graph, SEXP hops, SEXP color_types) {
  seams_system *sys = sys_of(ext);
  size_t n = 0;
  if (seams_system_natoms(sys, &n) != SEAMS_OK) {
    die(sys);
  }
  seams_topo *fp = NULL;
  if (seams_fingerprint(sys, Rf_asReal(cutoff), Rf_asInteger(type), Rf_asInteger(k),
                        Rf_asInteger(graph), Rf_asInteger(hops),
                        Rf_asInteger(color_types), &fp) != SEAMS_OK) {
    die(sys);
  }
  char saved[512];
  size_t key_len = 0;
  int code = seams_fingerprint_key(fp, NULL, 0, &key_len);
  char *key_buf = (char *)calloc(key_len + 1, 1);
  if (key_buf == NULL) {
    seams_fingerprint_destroy(fp);
    error("out of memory");
  }
  if (code == SEAMS_OK) {
    code = seams_fingerprint_key(fp, key_buf, key_len + 1, &key_len);
  }
  SEXP key_sexp = PROTECT(mkString(code == SEAMS_OK ? key_buf : ""));
  free(key_buf);

  SEXP atom_keys = PROTECT(allocVector(STRSXP, (R_xlen_t)n));
  for (size_t i = 0; i < n && code == SEAMS_OK; ++i) {
    size_t alen = 0;
    code = seams_fingerprint_atom(fp, (int)i, NULL, 0, &alen);
    if (code == SEAMS_OK) {
      char *abuf = (char *)calloc(alen + 1, 1);
      if (abuf == NULL) {
        seams_fingerprint_destroy(fp);
        error("out of memory");
      }
      code = seams_fingerprint_atom(fp, (int)i, abuf, alen + 1, &alen);
      if (code == SEAMS_OK) {
        SET_STRING_ELT(atom_keys, (R_xlen_t)i, mkChar(abuf));
      }
      free(abuf);
    }
  }
  SEXP rings = PROTECT(allocVector(INTSXP, 13));
  if (code == SEAMS_OK) {
    code = seams_fingerprint_rings(fp, INTEGER(rings), 13);
  }
  if (code != SEAMS_OK) {
    copy_error(fp, saved, sizeof(saved));
  }
  seams_fingerprint_destroy(fp);
  if (code != SEAMS_OK) {
    error("%s", saved);
  }
  SEXP out = PROTECT(allocVector(VECSXP, 3));
  SET_VECTOR_ELT(out, 0, key_sexp);
  SET_VECTOR_ELT(out, 1, atom_keys);
  SET_VECTOR_ELT(out, 2, rings);
  UNPROTECT(4);
  return out;
}

SEXP seams_r_brine(SEXP ext, SEXP ice, SEXP water_type, SEXP ion_type,
                   SEXP n_bins, SEXP axis) {
  seams_system *sys = sys_of(ext);
  if (TYPEOF(ice) != INTSXP) {
    error("ice must be an integer vector");
  }
  seams_brine *front = NULL;
  if (seams_brine_analyse(sys, INTEGER(ice), (size_t)LENGTH(ice),
                          Rf_asInteger(water_type), Rf_asInteger(ion_type),
                          Rf_asInteger(n_bins), Rf_asInteger(axis), &front) != SEAMS_OK) {
    die(sys);
  }
  double z_enter = 0.0, z_exit = 0.0, thickness = 0.0;
  int found = 0;
  double c_ice = 0.0, c_liquid = 0.0, k_rej = 0.0;
  int defined = 0;
  int n_pockets = 0, reservoir = 0;
  size_t prof_n = 0;
  int code = seams_brine_fronts(front, &z_enter, &z_exit, &thickness, &found);
  if (code == SEAMS_OK) {
    code = seams_brine_rejection(front, &c_ice, &c_liquid, &k_rej, &defined);
  }
  if (code == SEAMS_OK) {
    code = seams_brine_pockets(front, &n_pockets, &reservoir);
  }
  if (code == SEAMS_OK) {
    code = seams_brine_profile(front, NULL, NULL, NULL, 0, &prof_n);
  }
  SEXP z_mid = PROTECT(real_n((R_xlen_t)prof_n));
  SEXP molality = PROTECT(real_n((R_xlen_t)prof_n));
  SEXP ice_frac = PROTECT(real_n((R_xlen_t)prof_n));
  if (code == SEAMS_OK && prof_n > 0) {
    code = seams_brine_profile(front, REAL(z_mid), REAL(molality), REAL(ice_frac),
                               prof_n, &prof_n);
  }
  char saved[512];
  if (code != SEAMS_OK) {
    copy_error(front, saved, sizeof(saved));
  }
  seams_brine_destroy(front);
  if (code != SEAMS_OK) {
    error("%s", saved);
  }
  SEXP fronts = PROTECT(real_n(4));
  REAL(fronts)[0] = z_enter;
  REAL(fronts)[1] = z_exit;
  REAL(fronts)[2] = thickness;
  REAL(fronts)[3] = (double)found;
  SEXP rej = PROTECT(real_n(4));
  REAL(rej)[0] = c_ice;
  REAL(rej)[1] = c_liquid;
  REAL(rej)[2] = k_rej;
  REAL(rej)[3] = (double)defined;
  SEXP pockets = PROTECT(allocVector(INTSXP, 2));
  INTEGER(pockets)[0] = n_pockets;
  INTEGER(pockets)[1] = reservoir;
  SEXP out = PROTECT(allocVector(VECSXP, 6));
  SET_VECTOR_ELT(out, 0, fronts);
  SET_VECTOR_ELT(out, 1, rej);
  SET_VECTOR_ELT(out, 2, z_mid);
  SET_VECTOR_ELT(out, 3, molality);
  SET_VECTOR_ELT(out, 4, ice_frac);
  SET_VECTOR_ELT(out, 5, pockets);
  UNPROTECT(7);
  return out;
}

#ifdef DSEAMS_SPLIT_CAPI
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

static const R_CallMethodDef CapiEntries[] = {
  {"_dseams_seams_r_system", (DL_FUNC) &seams_r_system, 0},
  {"_dseams_seams_r_read", (DL_FUNC) &seams_r_read, 4},
  {"_dseams_seams_r_count", (DL_FUNC) &seams_r_count, 1},
  {"_dseams_seams_r_nframes", (DL_FUNC) &seams_r_nframes, 1},
  {"_dseams_seams_r_threads", (DL_FUNC) &seams_r_threads, 1},
  {"_dseams_seams_r_chill", (DL_FUNC) &seams_r_chill, 5},
  {"_dseams_seams_r_steinhardt", (DL_FUNC) &seams_r_steinhardt, 4},
  {"_dseams_seams_r_cages", (DL_FUNC) &seams_r_cages, 5},
  {"_dseams_seams_r_signature", (DL_FUNC) &seams_r_signature, 4},
  {"_dseams_seams_r_knn", (DL_FUNC) &seams_r_knn, 4},
  {"_dseams_seams_r_rdf", (DL_FUNC) &seams_r_rdf, 3},
  {"_dseams_seams_r_running_cn", (DL_FUNC) &seams_r_running_cn, 3},
  {"_dseams_seams_r_coordination", (DL_FUNC) &seams_r_coordination, 3},
  {"_dseams_seams_r_hbonds", (DL_FUNC) &seams_r_hbonds, 6},
  {"_dseams_seams_r_density", (DL_FUNC) &seams_r_density, 4},
  {"_dseams_seams_r_fingerprint", (DL_FUNC) &seams_r_fingerprint, 3},
  {"_dseams_seams_r_pairs", (DL_FUNC) &seams_r_pairs, 2},
  {"_dseams_seams_r_domains", (DL_FUNC) &seams_r_domains, 4},
  {"_dseams_seams_r_prisms", (DL_FUNC) &seams_r_prisms, 2},
  {"_dseams_seams_r_monolayer", (DL_FUNC) &seams_r_monolayer, 4},
  {"_dseams_seams_r_vertices", (DL_FUNC) &seams_r_vertices, 4},
  {"_dseams_seams_r_site", (DL_FUNC) &seams_r_site, 2},
  {"_dseams_seams_r_capi_info", (DL_FUNC) &seams_r_capi_info, 0},
  {"_dseams_seams_r_label_name", (DL_FUNC) &seams_r_label_name, 1},
  {"_dseams_seams_r_ring_symmetry_name", (DL_FUNC) &seams_r_ring_symmetry_name, 1},
  {"_dseams_seams_r_set_atoms", (DL_FUNC) &seams_r_set_atoms, 5},
  {"_dseams_seams_r_box", (DL_FUNC) &seams_r_box, 1},
  {"_dseams_seams_r_positions", (DL_FUNC) &seams_r_positions, 1},
  {"_dseams_seams_r_types", (DL_FUNC) &seams_r_types, 1},
  {"_dseams_seams_r_ids", (DL_FUNC) &seams_r_ids, 1},
  {"_dseams_seams_r_system_symmetry", (DL_FUNC) &seams_r_system_symmetry, 2},
  {"_dseams_seams_r_q4q6", (DL_FUNC) &seams_r_q4q6, 3},
  {"_dseams_seams_r_q6bar", (DL_FUNC) &seams_r_q6bar, 4},
  {"_dseams_seams_r_ql", (DL_FUNC) &seams_r_ql, 5},
  {"_dseams_seams_r_cages_labels", (DL_FUNC) &seams_r_cages_labels, 6},
  {"_dseams_seams_r_signature_edge", (DL_FUNC) &seams_r_signature_edge, 6},
  {"_dseams_seams_r_neighbours", (DL_FUNC) &seams_r_neighbours, 4},
  {"_dseams_seams_r_rings", (DL_FUNC) &seams_r_rings, 5},
  {"_dseams_seams_r_rings_chordless", (DL_FUNC) &seams_r_rings_chordless, 5},
  {"_dseams_seams_r_fingerprint_atoms", (DL_FUNC) &seams_r_fingerprint_atoms, 7},
  {"_dseams_seams_r_brine", (DL_FUNC) &seams_r_brine, 6},
  {NULL, NULL, 0}
};

attribute_visible void R_init_dseams_capi(DllInfo *dll) {
  R_registerRoutines(dll, NULL, CapiEntries, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
#endif
