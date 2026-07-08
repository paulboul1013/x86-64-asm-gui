# x86-64_gui

## introduce
simple gui with nasm and x86-64 platform x11 server

## usage
```bash
nasm -f elf64 -g main.nasm && ld main.o -static -o main
```
` Executable and Linkable Format (ELF) is part of the System V ABI`


## debug program

### check program types
```bash
file ./main
```

---
### check program sections
```bash
readelf -a ./main
```

---

### check program return code
```bash
./main; echo $?
```

---

### check program system calls
```bash
strace ./main
```

---

## asm knowledge

### system V ABI
https://wiki.osdev.org/System_V_ABI  
for system V ABI，before call function，stack pointer must be aligned `16` bytes
。otherwise the stack pointer value will be `16*N+8`。since before function be called，the pointer value is aligned 16-byte。

---

every push command will decrease `8` bytes of stack pointer value，so into function call still `16` bytes aligned

---

If don't know how stack size decrease is match 16 bytes aligned，you can do this
example:allocate 100 bytes on stack and then align 16 bytes
rsp = 0x1000
```bash
sub rsp ,100 ; 0x1000-100 = 0x994
and rsp, -16 ; 0x994 & 0xfffffff0 = 0x990
```
the stack size is 100 bytes，but the stack pointer address is 0x990，so the actual stack size is `0x1000-0x990 = 112` bytes

---


### x11 handshake Connection Setup Request, 12-byte fixed header
```c
typedef struct {
    uint8_t  byte_order;       // 'l' = little endian, 'B' = big endian
    uint8_t  unused1;

    uint16_t major_version;    // usually 11
    uint16_t minor_version;    // usually 0

    uint16_t auth_name_len;    // authorization protocol name length, in bytes
    uint16_t auth_data_len;    // authorization protocol data length, in bytes

    uint16_t unused2;

    /*
        Followed by:

        uint8_t auth_name[auth_name_len];
        padding to 4-byte boundary;

        uint8_t auth_data[auth_data_len];
        padding to 4-byte boundary;
    */
} x11_connection_setup_request_t;
```


### Server → Client: Setup Response Prefix
```c
typedef struct {
    uint8_t  status;               // 0 = Failed, 1 = Success, 2 = Authenticate
    uint8_t  reason_len;           // used when Failed or Authenticate

    uint16_t major_version;
    uint16_t minor_version;

    uint16_t additional_len;       // in 4-byte units
} x11_setup_response_prefix_t;

```

### Server → Client: Setup Success Body
If : status is 1 (Success), the following fields are present:
```c
typedef struct {
    uint32_t release_number;              // offset 0

    uint32_t resource_id_base;            // offset 4
    uint32_t resource_id_mask;            // offset 8

    uint32_t motion_buffer_size;          // offset 12

    uint16_t vendor_len;                  // offset 16
    uint16_t maximum_request_length;      // offset 18

    uint8_t  roots_len;                   // offset 20
    uint8_t  pixmap_formats_len;          // offset 21

    uint8_t  image_byte_order;            // offset 22
    uint8_t  bitmap_format_bit_order;     // offset 23

    uint8_t  bitmap_format_scanline_unit; // offset 24
    uint8_t  bitmap_format_scanline_pad;  // offset 25

    uint8_t  min_keycode;                 // offset 26
    uint8_t  max_keycode;                 // offset 27

    uint32_t unused;                      // offset 28
} x11_setup_success_body_t;
```