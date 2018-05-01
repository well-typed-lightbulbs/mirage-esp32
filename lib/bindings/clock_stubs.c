#include <esp_timer.h>
#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/fail.h>

#include <sys/types.h>
#include <sys/time.h>

// Returns time since boot in microseconds.
CAMLprim value
caml_get_monotonic_time(value v_unit)
{
    CAMLparam1(v_unit);
    printf("caml_get_monotonic_time called\n");
    CAMLreturn(caml_copy_int64(esp_timer_get_time()));
}

CAMLprim value unix_gettimeofday(value unit)
{
  struct timeval tp;
  if (gettimeofday(&tp, NULL) == -1) {
    caml_failwith("gettimeofday");
  }
  return copy_double((double) tp.tv_sec + (double) tp.tv_usec / 1e6);
}
