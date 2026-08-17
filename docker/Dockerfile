FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        python3 \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

# arduino-cli
RUN curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh \
    && mv ./bin/arduino-cli /usr/local/bin/arduino-cli

# ESP32 core + libraries used by BSB-LAN (baked in so `docker run` doesn't need network access)
RUN arduino-cli core update-index \
    && arduino-cli core install esp32:esp32 \
    && arduino-cli lib install Ethernet

RUN python3 -m pip install --no-cache-dir esptool

# BSB-LAN source, as of the commit the image was built from
WORKDIR /workspace
COPY . /workspace

# Custom 16MB partition table (needed for the esp32-poe-iso-16mb target)
RUN PARTDIR=$(echo /root/.arduino15/packages/esp32/hardware/esp32/*/tools/partitions) \
    && cp BSB_LAN/partitions/default_16MB.csv "$PARTDIR/default_16MB.csv"

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["esp32-devkit"]
