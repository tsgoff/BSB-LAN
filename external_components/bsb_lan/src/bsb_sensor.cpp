#include "bsb_sensor.h"
#include "esphome/core/log.h"

namespace esphome {
namespace bsb_lan {

static const char *const TAG = "bsb_sensor";

void BSBLANSensor::update() {
  auto *protocol = this->parent_->get_protocol();
  if (protocol == nullptr)
    return;

  std::vector<uint8_t> rx_msg;
  // We use the parameter as the command ID directly for now
  // In a full implementation, we'd need a lookup table to map
  // parameter numbers (e.g. 8700) to command IDs (e.g. 0x053D050E)
  if (protocol->send(TYPE_QUR, this->parameter_, rx_msg)) {
    // Basic decoding based on type
    float value = NAN;
    uint8_t pl_start = protocol->get_pl_start();

    if (rx_msg.size() > pl_start) {
      switch (this->type_) {
      case VT_TEMP: {
        int16_t raw = (rx_msg[pl_start] << 8) | rx_msg[pl_start + 1];
        value = raw / 64.0;
        break;
      }
      case VT_TEMP_SHORT5: {
        int16_t raw = (rx_msg[pl_start] << 8) | rx_msg[pl_start + 1];
        value = raw / 2.0;
        break;
      }
      case VT_PRESSURE: {
        int16_t raw = (rx_msg[pl_start] << 8) | rx_msg[pl_start + 1];
        value = raw / 10.0;
        break;
      }
      case VT_PERCENT: {
        value = rx_msg[pl_start];
        break;
      }
      default:
        ESP_LOGW(TAG, "Unsupported value type: %d", this->type_);
        break;
      }
    }

    if (!std::isnan(value)) {
      this->publish_state(value);
    }
  } else {
    ESP_LOGW(TAG, "Failed to query parameter 0x%08X", this->parameter_);
  }
}

void BSBLANSensor::dump_config() {
  LOG_SENSOR("", "BSB-LAN Sensor", this);
  ESP_LOGCONFIG(TAG, "  Parameter: 0x%08X", this->parameter_);
  ESP_LOGCONFIG(TAG, "  Value Type: %d", this->type_);
}

} // namespace bsb_lan
} // namespace esphome
