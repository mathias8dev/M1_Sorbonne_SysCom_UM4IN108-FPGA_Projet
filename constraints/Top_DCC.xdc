## Contraintes XDC pour Top_DCC - Basys 3
## Centrale DCC - Sortie sur JB[4]

## Horloge 100 MHz
set_property PACKAGE_PIN W5 [get_ports Clk_100MHz]
    set_property IOSTANDARD LVCMOS33 [get_ports Clk_100MHz]
    create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports Clk_100MHz]

## Reset (Bouton Centre)
set_property PACKAGE_PIN U18 [get_ports Reset]
    set_property IOSTANDARD LVCMOS33 [get_ports Reset]

## Interrupteurs (SW0 a SW7)
set_property PACKAGE_PIN V17 [get_ports {Interrupteur[0]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {Interrupteur[0]}]
set_property PACKAGE_PIN V16 [get_ports {Interrupteur[1]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {Interrupteur[1]}]
set_property PACKAGE_PIN W16 [get_ports {Interrupteur[2]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {Interrupteur[2]}]
set_property PACKAGE_PIN W17 [get_ports {Interrupteur[3]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {Interrupteur[3]}]
set_property PACKAGE_PIN W15 [get_ports {Interrupteur[4]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {Interrupteur[4]}]
set_property PACKAGE_PIN V15 [get_ports {Interrupteur[5]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {Interrupteur[5]}]
set_property PACKAGE_PIN W14 [get_ports {Interrupteur[6]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {Interrupteur[6]}]
set_property PACKAGE_PIN W13 [get_ports {Interrupteur[7]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {Interrupteur[7]}]

## Sortie DCC sur PMOD B broche 4 (JB[4] = JB7 sur schema)
set_property PACKAGE_PIN A15 [get_ports Sortie_DCC]
    set_property IOSTANDARD LVCMOS33 [get_ports Sortie_DCC]

## Configuration
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
