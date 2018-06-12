#include <esp_heap_caps.h>

#include <stdio.h>
#include <stdlib.h>

#include <caml/mlvalues.h>
#include <caml/memory.h>

CAMLprim value
stub_heap_get_pages_total(__attribute__((unused)) value unit) // noalloc
{
    multi_heap_info_t info;
    heap_caps_get_info(&info, MALLOC_CAP_DEFAULT);
    fprintf(stderr, "mm_stubs.c: pages_total: watch out, not sure of this implementation!\n");
	return Val_long(info.total_free_bytes + info.total_allocated_bytes);
}

CAMLprim value
stub_heap_get_pages_used(__attribute__((unused)) value unit) // noalloc
{
    multi_heap_info_t info;
    heap_caps_get_info(&info, MALLOC_CAP_DEFAULT);
    fprintf(stderr, "mm_stubs.c: pages_used: watch out, not sure of this implementation!\n");
	return Val_long(info.total_allocated_bytes);
}