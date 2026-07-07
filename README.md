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


