#pragma once

#include "bsb_lan.h"
#include "bsb_types.h"
#include "esphome/components/sensor/sensor.h"
#include "esphome/core/component.h"

namespace esphome {
namespace bsb_lan {

class BSBLANSensor : public sensor::Sensor, public PollingComponent {
public:
  void set_parent(BSBLANComponent *parent) { this->parent_ = parent; }
  void set_parameter(uint32_t parameter) { this->parameter_ = parameter; }
  void set_value_type(ValueType type) { this->type_ = type; }

  void update() override;
  void dump_config() override;

protected:
  BSBLANComponent *parent_;
  uint32_t parameter_;
  ValueType type_{VT_TEMP};
};

} // namespace bsb_lan
} // namespace esphome
