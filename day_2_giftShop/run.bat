@echo off
ghdl --clean
ghdl -a --std=08 day_2_pkg.vhdl day_2.vhdl day_2_tb.vhdl
ghdl -e --std=08 tb_productID
ghdl -r --std=08 tb_productID --vcd=wave.vcd
