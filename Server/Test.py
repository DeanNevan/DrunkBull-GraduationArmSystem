import struct

num = 12345
a = struct.pack(">I", num)
print(a)

b = struct.unpack(">I", a)
print(b)
