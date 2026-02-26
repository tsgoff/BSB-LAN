#pragma once

#include "bsb_protocol.h"
#include "esphome/components/uart/uart.h"
#include "esphome/core/component.h"

namespace esphome {
namespace bsb_lan {

class BSBLANComponent : public Component, public uart::UARTDevice {
public:
  void setup() override;
  void dump_config() override;
  float get_setup_priority() const override { return setup_priority::BUS; }

  void set_bus_type(BusType bus_type) { this->bus_type_ = bus_type; }
  void set_dest_addr(uint8_t addr) { this->dest_addr_ = addr; }
  void set_my_addr(uint8_t addr) { this->my_addr_ = addr; }

  BSBProtocol *get_protocol() { return this->protocol_.get(); }

protected:
  std::unique_ptr<BSBProtocol> protocol_;
  BusType bus_type_{BUS_BSB};
  uint8_t dest_addr_{0x00};
  uint8_t my_addr_{0x42};
};

} // namespace bsb_lan
} // namespace esphome
