![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg)

## Karplus-Strong String Synthesis for Tiny Tapeout
This is simplified implementation of Karplus-Strong (KS) string synthesis based on papers, [Digital Synthesis of Plucked-String and Drum Timbres](https://doi.org/10.2307/3680062) and [Extensions of the Karplus-Strong Plucked-String Algorithm](https://doi.org/10.2307/3680063). 

A register map controls and configures the KS synthesis module. This register map is accessed through a SPI interface. Synthesized sound samples are sent out through the I2S transmitter interface.

### SPI Frame
SPI Mode: CPOL = 0, CPHA = 1

The 16-bit SPI frame is defined as,

|     |     |     |
|:---:|:---:|:---:|
| Read=1/Write=0 | Address[6:0] | Data[7:0] |


### Register Map
The Register Map has 16 Registers of 8-bits each. It is divided into configuration and status registers,

|     |     |
|:--- |:--- |
| Register[7:0] | Configuration Registers |
| Register[11:8 ]| Status Registers |

Each register is mapped as follows,

| Register/Bit | 7                  | 6                   | 5             | 4              | 3             | 2                     | 1             | 0              |
|:------------:|:------------------:|:-------------------:|:-------------:|:--------------:|:-------------:|:---------------------:|:-------------:|:--------------:|
| 0            | i2s_noise_sel      | ks_freeze           | freeze_prbs_7 | freeze_prbs_15 |               | ~rst_n_ks_string      | ~rst_n_prbs_7 | ~rst_n_prbs_15 |
| 1            | ~lfsr_init_15[7:0] |                     |               |                |               |                       |               |                |
| 2            | load_prbs_15       | ~lfsr_init_15[14:8] |               |                |               |                       |               |                |
| 3            | load_prbs_7        | ~lfsr_init_7[6:0]   |               |                |               |                       |               |                |
| 4            |                    |                     | dynamics_en   | fine_tune_n    | drum_string_n | toggle_pattern_prbs_n | round_en      | pluck          |
| 5            | fine_tune_C[7:0]   |                     |               |                |               |                       |               |                |
| 6            | dynamics_R[7:0]    |                     |               |                |               |                       |               |                |
| 7            | ks_period[7:0]     |                     |               |                |               |                       |               |                |
| 9            | 1                  | 1                   | 0             | 0              | 0             | 0                     | 0             | 0              |
| 10           | 0                  | 0                   | 0             | 0              | 0             | 0                     | 0             | 1              |
| 11           | ui_in[7]           | ui_in[6]            | ui_in[5]      | ui_in[4]       | ui_in[3]      | ui_in[2]              | ui_in[1]      | ui_in[0]       |
| 12           |                    |                     |               |                |               |                       |               |                |

### I2S Transmitter
The 8-bit signed sound samples are sent out at `f_sck = 256 kHz` through this interface.

### How to use
Connect a clock with frequency `f_clk = 256 kHz` and apply a reset cycle to initialize the design, this sets the audio sample rate at `fs = 16 kHz`. Use the spi register map or the `ui_in` to futher configure the design. The synthesized samples are sent continuously through the I2S transmitter interface.

#### A description of what the inputs do (e.g. red button, SPI CLK, SPI MOSI, etc).
  inputs:               
  - ~rst_n_prbs_15, ~rst_n_prbs_7
  - load_prbs_15, load_prbs_7 
  - freeze_prbs_15
  - freeze_prbs_7
  - i2s_noise_sel
  - ~rst_n_ks_string
  - pluck
  - NOT CONNECTED
#### A description of what the outputs do (e.g. status LED, SPI MISO, etc)
  outputs:
  - segment a: rstn_n
  - segment b: rst_n_prbs_15
  - segment c: rst_n_prbs_7
  - segment d: rst_n_ks_string
  - segment e: freeze_prbs_15
  - segment f: freeze_prbs_15
  - segment g: i2s_noise_sel
  - dot: pluck
#### A description of what the bidirectional I/O pins do (e.g. I2C SDA, I2C SCL, etc)
  bidirectional:
  - sck_i
  - sdi_i
  - sdo_o
  - cs_ni
  - i2s_sck_o
  - i2s_ws_o
  - i2s_sd_o 
  - prbs_15

# What is Tiny Tapeout?

TinyTapeout is an educational project that aims to make it easier and cheaper than ever to get your digital designs manufactured on a real chip!

Go to https://tinytapeout.com for instructions!

## How to change the Wokwi project

Edit the [info.yaml](info.yaml) and change the wokwi_id to match your project.

## How to enable the GitHub actions to build the ASIC files

Please see the instructions for:

- [Enabling GitHub Actions](https://tinytapeout.com/faq/#when-i-commit-my-change-the-gds-action-isnt-running)
- [Enabling GitHub Pages](https://tinytapeout.com/faq/#my-github-action-is-failing-on-the-pages-part)

## How does it work?

When you edit the info.yaml to choose a different ID, the [GitHub Action](.github/workflows/gds.yaml) will fetch the digital netlist of your design from Wokwi.

After that, the action uses the open source ASIC tool called [OpenLane](https://www.zerotoasiccourse.com/terminology/openlane/) to build the files needed to fabricate an ASIC.

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://discord.gg/rPK2nSjxy8)

## What next?

- Share your GDS on Twitter, tag it [#tinytapeout](https://twitter.com/hashtag/tinytapeout?src=hashtag_click) and [link me](https://twitter.com/matthewvenn)!
