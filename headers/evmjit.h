#pragma once

#include <evm.h>

#ifdef C2NIM
  #  def EXPORT
  #  dynlib libevmjit
  #  cdecl
  #  if defined(windows)
  #    define libevmjit "libevmjit.dll"
  #  elif defined(macosx)
  #    define libevmjit "libevmjit.dylib"
  #  else
  #    define libevmjit "libevmjit.so"
  #  endif
  #  mangle uint32_t uint32
  #  mangle uint16_t uint16
  #  mangle uint8_t  uint8
  #  mangle uint64_t uint64
  #  mangle int32_t  int32
  #  mangle int16_t  int16
  #  mangle int8_t   int8
  #  mangle int64_t  int64
  #  mangle cuchar   uint8
#else
  #ifdef _MSC_VER
  #ifdef evmjit_EXPORTS
  #define EXPORT __declspec(dllexport)
  #else
  #define EXPORT
  #endif

  #else
  #define EXPORT __attribute__ ((visibility ("default")))
  #endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

/// Create EVMJIT instance.
///
/// @return  The EVMJIT instance.
EXPORT struct evm_instance* evmjit_create(void);

#ifdef __cplusplus
}
#endif
