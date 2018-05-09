(** ESP32 API calls results **)
type esp_result = 
  | ESP32_OK
  | ESP32_AGAIN
  | ESP32_EINVAL
  | ESP32_EUNSPEC