#include <esp_timer.h>
#include <caml/mlvalues.h>

// Returns time since boot in microseconds.
CAMLprim value
caml_get_monotonic_time(value v_unit)
{
    CAMLparam1(v_unit);
    CAMLreturn(Val_int(esp_timer_get_time()));
}