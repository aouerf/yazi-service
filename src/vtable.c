#include <systemd/sd-bus.h>

// sd_bus_message_handler_t
extern int handle_bus_message(sd_bus_message *m, void *userdata,
                              sd_bus_error *ret_error);

// https://www.freedesktop.org/wiki/Specifications/file-manager-interface/
// org.freedesktop.FileManager1
const sd_bus_vtable vtable[] = {
    SD_BUS_VTABLE_START(0),
    SD_BUS_METHOD("ShowFolders", "ass", NULL, handle_bus_message, 0),
    SD_BUS_METHOD("ShowItems", "ass", NULL, handle_bus_message, 0),
    SD_BUS_METHOD("ShowItemProperties", "ass", NULL, handle_bus_message, 0),
    SD_BUS_VTABLE_END,
};

const sd_bus_vtable *get_vtable() { return vtable; }
