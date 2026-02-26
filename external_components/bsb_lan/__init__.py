import esphome.codegen as cg
import esphome.config_validation as cv
from esphome.components import uart
from esphome.const import CONF_ID

DEPENDENCIES = ["uart"]
AUTO_LOAD = ["sensor", "number", "binary_sensor"]

bsb_lan_ns = cg.esphome_ns.namespace("bsb_lan")
BSBLANComponent = bsb_lan_ns.class_("BSBLANComponent", cg.Component, uart.UARTDevice)
BusType = bsb_lan_ns.enum("BusType")

BUS_TYPES = {
    "BSB": BusType.BUS_BSB,
    "LPB": BusType.BUS_LPB,
    "PPS": BusType.BUS_PPS,
}

CONF_BUS_TYPE = "bus_type"
CONF_DEST_ADDR = "dest_addr"
CONF_MY_ADDR = "my_addr"

CONFIG_SCHEMA = cv.Schema(
    {
        cv.GenerateID(): cv.declare_id(BSBLANComponent),
        cv.Optional(CONF_BUS_TYPE, default="BSB"): cv.enum(BUS_TYPES, upper=True),
        cv.Optional(CONF_DEST_ADDR, default=0x00): cv.uint8_t,
        cv.Optional(CONF_MY_ADDR, default=0x42): cv.uint8_t,
    }
).extend(cv.COMPONENT_SCHEMA).extend(uart.UART_DEVICE_SCHEMA)

async def to_code(config):
    var = cg.new_Pvariable(config[CONF_ID])
    await cg.register_component(var, config)
    await uart.register_uart_device(var, config)

    cg.add(var.set_bus_type(config[CONF_BUS_TYPE]))
    cg.add(var.set_dest_addr(config[CONF_DEST_ADDR]))
    cg.add(var.set_my_addr(config[CONF_MY_ADDR]))
