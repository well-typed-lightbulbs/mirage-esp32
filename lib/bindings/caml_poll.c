#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/callback.h>
#include <caml/alloc.h>

#include <sys/types.h>
#include <sys/time.h>
#include <sys/unistd.h>
#include <esp_timer.h>

CAMLprim value
caml_poll(value v_deadline)
{
    CAMLparam1(v_deadline);

    int64_t deadline = Int64_val(v_deadline);
    int64_t cur_time = esp_timer_get_time();

    if (deadline <= cur_time) {
        CAMLreturn(Val_bool(0));
    } 

    usleep((deadline - cur_time)/1000);

    CAMLreturn(Val_bool(0));
}