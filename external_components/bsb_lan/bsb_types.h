#pragma once

#include <cstdint>

namespace esphome {
namespace bsb_lan {

enum ValueType : uint16_t {
  VT_TEMP = 750,        // 3 Byte - value/64
  VT_PRESSURE = 671,    // 2 Byte - bar/10.0
  VT_PERCENT = 667,     // 2 Byte - percent
  VT_TEMP_SHORT5 = 683, // 2 Byte - value/2
  VT_ONOFF = 666,       // 2 Byte - 0=Off, 1=On
  VT_SECONDS_WORD = 738 // 3 Byte - seconds
};

enum MessageType : uint8_t {
  TYPE_QUR = 0x06, // query parameter
  TYPE_ANS = 0x07, // answer query
  TYPE_ERR = 0x08  // error
};

} // namespace bsb_lan
} // namespace esphome
