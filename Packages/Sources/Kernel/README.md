# Kernel Package

This directory contains the files make up the kernel that does the actual filtering of audio samples. Most of the
actual work is performed in classes defined in C++ header files. There is a Obj-C++
[Adapter](Sources/Kernel/Adapter.h) class that provides an interface that Swift can use, but it just wraps a C++ Kernel
object.

- [Adapter](Sources/Kernel/Adapter.h) -- provides simple interface in Obj-C for the kernel.

- [C++](C++) -- holds the C++ header files that perform the actual sample rendering.

- [include](include) -- holds just a [Kernel.h](Sources/Kernel/include/Kernel.h) file that controls what items
  are exposed to Swift.
