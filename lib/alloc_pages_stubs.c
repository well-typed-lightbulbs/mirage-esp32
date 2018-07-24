#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define PAGE_SIZE 4096

#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/fail.h>
#include <caml/bigarray.h>

/* Allocate a page-aligned bigarray of length [n_pages] pages.
   Since CAML_BA_MANAGED is set the bigarray C finaliser will
   call free() whenever all sub-bigarrays are unreachable.
 */
CAMLprim value
mirage_alloc_pages(value did_gc, value n_pages)
{
  CAMLparam2(did_gc, n_pages);
  size_t len = Int_val(n_pages) * PAGE_SIZE;
  /* If the allocation fails, return None. The ocaml layer will
     be able to trigger a full GC which just might run finalizers
     of unused bigarrays which will free some memory. */
  void* block = malloc(len);
  if (block == NULL) {
    if (Bool_val(did_gc))
      printf("ERROR: Io_page: memalign(%d, %zu) failed, even after GC.\n", PAGE_SIZE, len);
    caml_raise_out_of_memory();
  }
  /* Explicitly zero the page before returning it */
  memset(block, 0, len);

/* OCaml 4.02 introduced bigarray element type CAML_BA_CHAR,
   which needs to be used - otherwise type t in io_page.ml
   is different from the allocated bigarray and equality won't
   hold.
   Only since 4.02 there is a <caml/version.h>, thus we cannot
   include it in order to detect the version of the OCaml runtime.
   Instead, we use definitions which were introduced by 4.02 - and
   cross fingers that they'll stay there in the future.
   Once <4.02 support is removed, we should get rid of this hack.
   -- hannes, 16th Feb 2015
 */
#ifdef Caml_ba_kind_val
  CAMLreturn(caml_ba_alloc_dims(CAML_BA_CHAR | CAML_BA_C_LAYOUT | CAML_BA_MANAGED, 1, block, len));
#else
  CAMLreturn(caml_ba_alloc_dims(CAML_BA_UINT8 | CAML_BA_C_LAYOUT | CAML_BA_MANAGED, 1, block, len));
#endif
}

CAMLprim value
mirage_get_addr(value page)
{
  CAMLparam1(page);
  CAMLlocal1(nativeint);
  void *data = Caml_ba_data_val(page);
  nativeint = caml_copy_nativeint((intnat) data);
  CAMLreturn(nativeint);
}
