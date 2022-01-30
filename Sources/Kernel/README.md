# Kernel Package

This directory contains the files make up the kernel that does the actual filtering of audio samples.

- [KernelAdapter](KernelAdapter.hpp) -- provides simple interface in Obj-C for the kernel.

- [C++](C++) -- holds the C++ header files that perform the actual sample rendering.

- [include](include) -- holds just a [Kernel.h](Sources/Kernel/include/Kernel.h) file that controls what items
  are exposed to Swift.
