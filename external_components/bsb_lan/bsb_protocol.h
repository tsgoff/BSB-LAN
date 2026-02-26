#pragma once

#include "esphome/core/component.h"
#include "esphome/components/uart/uart.h"
#include <vector>

namespace esphome {
namespace bsb_lan {

enum BusType {
  BUS_BSB = 0,
  BUS_LPB = 1,
  BUS_PPS = 2
};

enum BusStatus {
  BUS_OK = 1,
  BUS_NOTFREE = -1,
  BUS_NOMATCH = -2,
  BUS_ERROR = -3
};

class BSBProtocol {
 public:
  BSBProtocol(uart::UARTComponent *parent);

  void set_bus_type(BusType bus_type, uint8_t addr = 0x42, uint8_t d_addr = 0x00);
  
  bool send(uint8_t type, uint32_t cmd, std::vector<uint8_t> &rx_msg, const std::vector<uint8_t> &param = {});
  
  uint16_t calculate_crc(const uint8_t *buffer, uint8_t length);
  uint16_t calculate_crc_lpb(const uint8_t *buffer, uint8_t length);
  uint8_t calculate_crc_pps(const uint8_t *buffer, uint8_t length);

  uint8_t get_pl_start() const { return pl_start_; }

 protected:
  bool wait_for_free_bus();
  bool low_level_send(const std::vector<uint8_t> &msg);
  bool get_message(std::vector<uint8_t> &msg);
  
  uint8_t read_byte();
  void write_byte(uint8_t data);

  uart::UARTComponent *parent_;
  BusType bus_type_{BUS_BSB};
  uint8_t my_addr_{0x42};
  uint8_t dest_addr_{0x00};
  uint8_t len_idx_{3};
  uint8_t pl_start_{9};
  uint8_t offset_{0};
};

}  // namespace bsb_lan
}  // namespace esphome
