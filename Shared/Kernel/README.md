# Kernel Directory

This directory contains the files involved in filtering.

- [FilterKernel](FilterKernel.hpp) -- holds parameters that define the filter (cutoff and resonance) and applies the filter to
  samples during audio unit rendering.

- [FilterKernelAdapter](FilterKernelAdapter.h) -- tiny Objective-C wrapper for the [FilterKernel](FilterKernel.hpp) so that
  Swift can work with it

- [InputBuffer](InputBuffer.hpp) -- manages an [AVAudioPCMBuffer](https://developer.apple.com/documentation/avfaudio/avaudiopcmbuffer)
  that holds audio samples from an upstream node for processing by the filter.

- [KernelEventProcessor](KernelEventProcessor.hpp) -- templated base class that understands how to properly interleave events
  and sample renderings for sample-accurate events. Uses the "curiously recurring template pattern" to do so
  without need of virtual method calls. [FilterKernel](FilterKernel.hpp) derives from this.
