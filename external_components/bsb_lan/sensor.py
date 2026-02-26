import esphome.codegen as cg
import esphome.config_validation as cv
from esphome.components import sensor
from esphome.const import (
    CONF_ID,
    CONF_TYPE,
    CONF_UPDATE_INTERVAL,
)
from . import bsb_lan_ns, BSBLANComponent, BUS_TYPES

BSBLANSensor = bsb_lan_ns.class_("BSBLANSensor", sensor.Sensor, cg.PollingComponent)
ValueType = bsb_lan_ns.enum("ValueType")

VALUE_TYPES = {
    "TEMP": ValueType.VT_TEMP,
    "PRESSURE": ValueType.VT_PRESSURE,
    "PERCENT": ValueType.VT_PERCENT,
    "TEMP_SHORT5": ValueType.VT_TEMP_SHORT5,
    "ONOFF": ValueType.VT_ONOFF,
}

CONF_BSB_LAN_ID = "bsb_lan_id"
CONF_PARAMETER = "parameter"

CONFIG_SCHEMA = sensor.sensor_schema().extend(
    {
        cv.GenerateID(): cv.declare_id(BSBLANSensor),
        cv.GenerateID(CONF_BSB_LAN_ID): cv.use_id(BSBLANComponent),
        cv.Required(CONF_PARAMETER): cv.hex_uint32_t,
        cv.Optional(CONF_TYPE, default="TEMP"): cv.enum(VALUE_TYPES, upper=True),
        cv.Optional(CONF_UPDATE_INTERVAL, default="60s"): cv.update_interval,
    }
).extend(cv.polling_component_schema("60s"))

async def to_code(config):
    var = cg.new_Pvariable(config[CONF_ID])
    await cg.register_component(var, config)
    await sensor.register_sensor(var, config)

    parent = await cg.get_variable(config[CONF_BSB_LAN_ID])
    cg.add(var.set_parent(parent))
    cg.add(var.set_parameter(config[CONF_PARAMETER]))
    cg.add(var.set_value_type(config[CONF_TYPE]))
