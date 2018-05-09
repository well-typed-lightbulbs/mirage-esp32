
#include <string.h>

#define CAML_NAME_SPACE
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/signals.h>
#include <caml/fail.h>
#include <caml/callback.h>
#include <caml/bigarray.h>

#include "freertos/FreeRTOS.h"
#include "esp_wifi.h"
#include "esp_system.h"
#include "esp_event.h"
#include "esp_event_loop.h"
#include "nvs_flash.h"
#include "driver/gpio.h"
#include "esp_wifi_internal.h"
#include "esp.h"

#include "freertos/event_groups.h"

/*
 Wifi frame descriptors storage. 
 */
typedef struct frame_list {
    struct frame_list* next;
    uint16_t length;
    void* buffer;
    void* l2_frame; /* the whole frame, to free with `esp_wifi_internal_free_rx_buffer` after transmmission to the stack. */
} frame_list_t;



/* Event group to notify Mirage task when data is received*/
EventGroupHandle_t wifi_event_group;
const int ESP_FRAME_RECEIVED_BIT = BIT0;


static frame_list_t* frames_start = NULL;
static frame_list_t* frames_end = NULL;

/*
    Called by wifi code. Add an entry to the frames linked list. 
*/
esp_err_t packet_handler(void *buffer, uint16_t len, void *eb) {
    frame_list_t* entry = malloc(sizeof(frame_list_t));
    entry->next = NULL;
    entry->length = len,
    entry->buffer = buffer;
    entry->l2_frame = eb;
    if (frames_end != NULL) {
        frames_end->next = entry;
    } else {
        frames_start = entry;
    }
    frames_end = entry;
    xEventGroupSetBits(wifi_event_group, ESP_FRAME_RECEIVED_BIT);
    return ESP_OK;
}


esp_err_t event_handler(void *ctx, system_event_t *event)
{
    wifi_config_t sta_config = 
    {
        .sta = {
            .ssid = "EE-h3nmxr",
            .password = "clock-owe-ever",
            .bssid_set = false
        }
    };

    switch(event->event_id) {
        case SYSTEM_EVENT_STA_START:
            ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &sta_config));
            ESP_ERROR_CHECK(esp_wifi_connect());
            break;
        case SYSTEM_EVENT_STA_CONNECTED:
            ESP_ERROR_CHECK(esp_wifi_internal_reg_rxcb(WIFI_IF_STA, packet_handler));
            break;
        case SYSTEM_EVENT_STA_DISCONNECTED:
            ESP_ERROR_CHECK(esp_wifi_connect());
            break;
        default:
            break;
    }
    return ESP_OK;
}

void wifi_initialize()
{
    nvs_flash_init();
    tcpip_adapter_init();
    ESP_ERROR_CHECK( esp_event_loop_init(event_handler, NULL) );
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK( esp_wifi_init(&cfg) );
    ESP_ERROR_CHECK( esp_wifi_set_storage(WIFI_STORAGE_RAM) );
    ESP_ERROR_CHECK( esp_wifi_set_mode(WIFI_MODE_STA) );
    ESP_ERROR_CHECK( esp_wifi_start() );

    wifi_event_group = xEventGroupCreate();
}

/*
 CAML WRAPPERS
*/

/*
 Read MAC address and MTU of wifi card.
*/
CAMLprim value
mirage_esp32_net_info(value v_unit)
{
    CAMLparam1(v_unit);
    CAMLlocal2(v_mac_address, v_result);
    
    v_mac_address = caml_alloc_string(6);
    ESP_ERROR_CHECK(esp_wifi_get_mac(WIFI_IF_STA, (uint8_t*)String_val(v_mac_address)));
    v_result = caml_alloc(2, 0);
    Store_field(v_result, 0, v_mac_address);
    Store_field(v_result, 1, Val_long(1400));

    CAMLreturn(v_result);
}

CAMLprim value
mirage_esp32_net_read(value v_buf, value v_size)
{
    CAMLparam2(v_buf, v_size);
    CAMLlocal1(v_result);
    uint8_t *buf = Caml_ba_data_val(v_buf);
    size_t size = Long_val(v_size);

    size_t read_size;
    esp32_result_t result;

    frame_list_t* current_frame = frames_start;

    if (current_frame != NULL) {
        /* Check if destination buffer can contain the payload. If not, drop the payload. */
        if (current_frame->length > size) {
            result = ESP32_EINVAL;
            read_size = 0;
        } else {
            result = ESP32_OK;
            read_size = current_frame->length;
            memcpy(buf, current_frame->buffer, current_frame->length);

            /* Last frame in the list */
            if (frames_start == frames_end) {
                frames_start = NULL;
                frames_end = NULL;
            } else {
                frames_start = current_frame->next;
            }
            esp_wifi_internal_free_rx_buffer(current_frame->l2_frame);
            free(current_frame);

            if (frames_start == NULL) {
                xEventGroupClearBits(wifi_event_group, ESP_FRAME_RECEIVED_BIT);
            }
        }
    } else {
        result = ESP32_AGAIN;
        read_size = 0;
    }
    
    v_result = caml_alloc_tuple(2);
    Field(v_result, 0) = Val_int(result);
    Field(v_result, 1) = Val_long(read_size);
    CAMLreturn(v_result);
}

/*
 lwIP error codes
 */
#define ERR_OK 0
#define ERR_ARG -16

CAMLprim value
mirage_esp32_net_write(value v_buf, value v_size)
{
    CAMLparam2(v_buf, v_size);
    void *buf = Caml_ba_data_val(v_buf);
    size_t size = Long_val(v_size);
    esp32_result_t result;
    switch(esp_wifi_internal_tx(WIFI_IF_STA, buf, size)){
        case ERR_OK:
            result = ESP32_OK;
            break;
        case ERR_ARG:
            result = ESP32_EINVAL;
            break;
        default:
            result = ESP32_EUNSPEC;
            break;
    }
    CAMLreturn(Val_int(result));
}

