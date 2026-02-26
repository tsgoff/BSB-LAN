#include "bsb_lan.h"
#include "esphome/core/log.h"

namespace esphome {
namespace bsb_lan {

static const char *const TAG = "bsb_lan";

void BSBLANComponent::setup() {
  ESP_LOGCONFIG(TAG, "Setting up BSB-LAN...");
  this->protocol_ = std::make_unique<BSBProtocol>(this->parent_);
  this->protocol_->set_bus_type(this->bus_type_, this->my_addr_,
                                this->dest_addr_);
}

void BSBLANComponent::dump_config() {
  ESP_LOGCONFIG(TAG, "BSB-LAN:");
  ESP_LOGCONFIG(TAG, "  Bus Type: %d", this->bus_type_);
  ESP_LOGCONFIG(TAG, "  My Address: 0x%02X", this->my_addr_);
  ESP_LOGCONFIG(TAG, "  Dest Address: 0x%02X", this->dest_addr_);
}

} // namespace bsb_lan
} // namespace esphome
