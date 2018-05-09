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

extern EventGroupHandle_t wifi_event_group;
extern const int ESP_FRAME_RECEIVED_BIT;

CAMLprim value
caml_poll(value v_deadline)
{
    CAMLparam1(v_deadline);

    int64_t deadline = Int64_val(v_deadline);
    int64_t cur_time = esp_timer_get_time();


    if (deadline <= cur_time) {
        CAMLreturn(Val_bool(xEventGroupGetBits(wifi_event_group) & ESP_FRAME_RECEIVED_BIT));
    } 
    xEventGroupWaitBits(wifi_event_group, ESP_FRAME_RECEIVED_BIT, false, true, (deadline - cur_time)*configTICK_RATE_HZ/(1000*1000*1000));

    CAMLreturn(Val_bool(xEventGroupGetBits(wifi_event_group) & ESP_FRAME_RECEIVED_BIT));
}