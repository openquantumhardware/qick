# gen_dmem.py
data = [0]*16
data[3] = 0x0000000A
with open("dmem.hex", "w") as f:
    for d in data:
        f.write(f"{d:08X}\n")