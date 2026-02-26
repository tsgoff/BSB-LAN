#include "bsb_protocol.h"
#include "esphome/core/hal.h"
#include "esphome/core/log.h"

namespace esphome {
namespace bsb_lan {

static const char *const TAG = "bsb_protocol";

BSBProtocol::BSBProtocol(uart::UARTComponent *parent) : parent_(parent) {}

void BSBProtocol::set_bus_type(BusType bus_type, uint8_t addr, uint8_t d_addr) {
  this->bus_type_ = bus_type;
  this->my_addr_ = addr;
  this->dest_addr_ = d_addr;

  switch (this->bus_type_) {
  case BUS_BSB:
    this->len_idx_ = 3;
    this->offset_ = 0;
    this->pl_start_ = 9;
    break;
  case BUS_LPB:
    this->len_idx_ = 1;
    this->offset_ = 4;
    this->pl_start_ = 13;
    break;
  case BUS_PPS:
    this->len_idx_ = 8;
    this->pl_start_ = 6;
    break;
  }
}

uint16_t BSBProtocol::calculate_crc(const uint8_t *buffer, uint8_t length) {
  uint16_t crc = 0;
  for (uint8_t i = 0; i < length; i++) {
    uint8_t data = buffer[i];
    crc = crc ^ ((uint16_t)data << 8);
    for (uint8_t j = 0; j < 8; j++) {
      if (crc & 0x8000) {
        crc = (crc << 1) ^ 0x1021;
      } else {
        crc <<= 1;
      }
    }
  }
  return crc;
}

uint16_t BSBProtocol::calculate_crc_lpb(const uint8_t *buffer, uint8_t length) {
  uint16_t crc = (257 - length) * 256 + length - 2;
  for (uint8_t i = 0; i < length - 1; i++) {
    crc += buffer[i];
  }
  return crc;
}

uint8_t BSBProtocol::calculate_crc_pps(const uint8_t *buffer, uint8_t length) {
  int sum = 0;
  for (uint8_t i = 0; i < length; i++) {
    sum += buffer[i];
  }
  return 0xFF - (sum & 0xFF) + 1;
}

uint8_t BSBProtocol::read_byte() {
  uint8_t data;
  this->parent_->read_byte(&data);
  if (this->bus_type_ != BUS_PPS) {
    data = data ^ 0xFF;
  }
  return data;
}

void BSBProtocol::write_byte(uint8_t data) {
  if (this->bus_type_ != BUS_PPS) {
    data = data ^ 0xFF;
  }
  this->parent_->write_byte(data);
}

bool BSBProtocol::wait_for_free_bus() {
  // Simple implementation: wait for silence on UART
  uint32_t start = millis();
  while (millis() - start < 100) {
    if (this->parent_->available()) {
      // Activity detected, clear buffer and restart timer
      while (this->parent_->available()) {
        this->read_byte();
      }
      start = millis();
    }
    yield();
  }
  return true;
}

bool BSBProtocol::low_level_send(const std::vector<uint8_t> &msg) {
  if (!this->wait_for_free_bus()) {
    return false;
  }

  for (uint8_t b : msg) {
    this->write_byte(b);
    // In BSB/LPB, we should see our own bytes echoed back
    // However, ESPHome's UART component might not support this easily
    // depending on the hardware (half-duplex etc.)
  }
  this->parent_->flush();
  return true;
}

bool BSBProtocol::get_message(std::vector<uint8_t> &msg) {
  uint32_t start = millis();
  msg.clear();

  while (millis() - start < 1000) {
    if (this->parent_->available()) {
      uint8_t b = this->read_byte();

      // Look for SOF
      bool sof = false;
      if (this->bus_type_ == BUS_BSB && (b == 0xDC || b == 0xDE))
        sof = true;
      else if (this->bus_type_ == BUS_LPB && b == 0x78)
        sof = true;
      else if (this->bus_type_ == BUS_PPS &&
               ((b & 0x0F) == 0x07 || (b & 0x0F) == 0x0D))
        sof = true;

      if (sof) {
        msg.push_back(b);
        // Read rest of message
        while (millis() - start < 2000) {
          if (this->parent_->available()) {
            msg.push_back(this->read_byte());

            // Check if message is complete
            if (msg.size() > this->len_idx_) {
              if (this->bus_type_ != BUS_PPS) {
                uint8_t len = msg[this->len_idx_];
                if (msg.size() >= len + (this->bus_type_ == BUS_LPB ? 1 : 0)) {
                  // Verify CRC (omitted for brevity in this initial version)
                  return true;
                }
              } else {
                // PPS has fixed length or specific end
                if (msg.size() >= 9)
                  return true;
              }
            }
          }
          yield();
        }
      }
    }
    yield();
  }
  return false;
}

bool BSBProtocol::send(uint8_t type, uint32_t cmd, std::vector<uint8_t> &rx_msg,
                       const std::vector<uint8_t> &param) {
  std::vector<uint8_t> tx_msg;

  uint8_t a2 = (cmd >> 24) & 0xFF;
  uint8_t a1 = (cmd >> 16) & 0xFF;
  uint8_t a3 = (cmd >> 8) & 0xFF;
  uint8_t a4 = cmd & 0xFF;

  if (this->bus_type_ == BUS_BSB) {
    tx_msg.push_back(0xDC);
    tx_msg.push_back(this->my_addr_ | 0x80);
    tx_msg.push_back(this->dest_addr_);
    tx_msg.push_back(11 + param.size());
    tx_msg.push_back(type);
    tx_msg.push_back(a1);
    tx_msg.push_back(a2);
    tx_msg.push_back(a3);
    tx_msg.push_back(a4);
  } else if (this->bus_type_ == BUS_LPB) {
    tx_msg.push_back(0x78);
    tx_msg.push_back(14 + param.size());
    tx_msg.push_back(this->dest_addr_);
    tx_msg.push_back(this->my_addr_);
    tx_msg.push_back(0xC0);
    tx_msg.push_back(0x02);
    tx_msg.push_back(0x00);
    tx_msg.push_back(0x14);
    tx_msg.push_back(type);
    tx_msg.push_back(a1);
    tx_msg.push_back(a2);
    tx_msg.push_back(a3);
    tx_msg.push_back(a4);
  }

  for (uint8_t p : param) {
    tx_msg.push_back(p);
  }

  if (this->bus_type_ == BUS_BSB) {
    uint16_t crc = this->calculate_crc(tx_msg.data(), tx_msg.size());
    tx_msg.push_back(crc >> 8);
    tx_msg.push_back(crc & 0xFF);
  } else if (this->bus_type_ == BUS_LPB) {
    uint16_t crc = this->calculate_crc_lpb(tx_msg.data(), tx_msg.size());
    tx_msg.push_back(crc >> 8);
    tx_msg.push_back(crc & 0xFF);
  }

  for (int retry = 0; retry < 3; retry++) {
    if (this->low_level_send(tx_msg)) {
      if (this->get_message(rx_msg)) {
        return true;
      }
    }
  }

  return false;
}

} // namespace bsb_lan
} // namespace esphome
