#include <esp_timer.h>
#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>

// Returns time since boot in microseconds.
CAMLprim value
caml_get_monotonic_time(value v_unit)
{
    CAMLparam1(v_unit);
    CAMLreturn(caml_copy_int64(esp_timer_get_time()));
}