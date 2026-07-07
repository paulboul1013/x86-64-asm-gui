# x86-64_gui

## introduce
simple gui with nasm and x86-64 platform x11 server

## usage
```bash
nasm -f elf64 -g main.nasm && ld main.o -static -o main
```

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

