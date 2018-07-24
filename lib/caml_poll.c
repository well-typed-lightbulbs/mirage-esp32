#include <stdio.h>
#include <stdlib.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_system.h"
#include "freertos/event_groups.h"

#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/callback.h>
#include <caml/alloc.h>

#include <sys/types.h>
#include <sys/time.h>
#include <sys/unistd.h>
#include <esp_timer.h>

EventGroupHandle_t mirage_event_group;

/*
    Use the polling feature of FreeRTOS to wait for a partical set of events given in argument.
*/
CAMLprim value
caml_poll(value v_deadline, value v_events)
{
    CAMLparam2(v_deadline, v_events);

    int64_t deadline = Int64_val(v_deadline);
    int     events   = Int_val(v_events);
    int64_t cur_time = esp_timer_get_time();

    if (deadline <= cur_time) {
        CAMLreturn(Val_int(xEventGroupGetBits(mirage_event_group) & events));
    } 

    if (events == 0) {
        vTaskDelay((deadline - cur_time)*configTICK_RATE_HZ/(1000*1000));
    } else {
        xEventGroupWaitBits(mirage_event_group, events, false, false, (deadline - cur_time)*configTICK_RATE_HZ/(1000*1000));
    }
    
    CAMLreturn(Val_int(xEventGroupGetBits(mirage_event_group) & events));

}

/*
    Polling mechanism rely on the creation of an event group.
    (https://www.freertos.org/FreeRTOS-Event-Groups.html)
*/
CAMLprim value
caml_poll_initialize(value unit) {
    CAMLparam0();
    mirage_event_group = xEventGroupCreate();
    CAMLreturn(Val_unit);
}

