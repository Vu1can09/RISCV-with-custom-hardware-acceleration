# OpenROAD Physical Design Script for RISC-V Accelerator
# Target Node: Skywater 130nm

set PDK "$env(MY_PDK)/sky130A/libs.ref/sky130_fd_sc_hd"

puts "==== 1. Loading Tech LEF and Standard Cell Libraries ===="
read_lef $PDK/techlef/sky130_fd_sc_hd__nom.tlef
read_lef $PDK/lef/sky130_fd_sc_hd.lef
read_liberty $PDK/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

puts "==== 2. Loading Synthesized Netlist ===="
read_verilog build/riscv_core_top_synth.v
link_design riscv_core_top

puts "==== 3. Defining Constraints (SDC) ===="
set sdc_file build/timing.sdc
set sdc_out [open $sdc_file w]
# Target clock: 15ns (66.6 MHz)
puts $sdc_out "create_clock -name clk -period 15.0 \[get_ports clk\]"
close $sdc_out
read_sdc $sdc_file

puts "==== 4. Initializing Floorplan ===="
# Die area: 400um x 400um, Core area: 5um margin
initialize_floorplan -site unithd \
    -die_area "0 0 400 400" \
    -core_area "5 5 395 395"

puts "==== 5. Generating Routing Tracks ===="
# Define routing tracks natively for Sky130 since TLEF lacks them
make_tracks li1  -x_offset 0.23 -y_offset 0.17 -x_pitch 0.46 -y_pitch 0.34
make_tracks met1 -x_offset 0.17 -y_offset 0.23 -x_pitch 0.34 -y_pitch 0.46
make_tracks met2 -x_offset 0.23 -y_offset 0.17 -x_pitch 0.46 -y_pitch 0.34
make_tracks met3 -x_offset 0.34 -y_offset 0.34 -x_pitch 0.68 -y_pitch 0.68
make_tracks met4 -x_offset 0.46 -y_offset 0.46 -x_pitch 0.92 -y_pitch 0.92
make_tracks met5 -x_offset 1.70 -y_offset 1.70 -x_pitch 3.40 -y_pitch 3.40

puts "==== 6. Adding Tap and Decap cells ===="
tapcell -distance 14 -tapcell_master "sky130_fd_sc_hd__tapvpwrvgnd_1" -endcap_master "sky130_fd_sc_hd__decap_4"

puts "==== 7. Global and Detailed Placement ===="
place_pins -random -hor_layers met3 -ver_layers met4
global_placement -density 0.6
detailed_placement

puts "==== 8. Clock Tree Synthesis (CTS) ===="
clock_tree_synthesis -root_buf sky130_fd_sc_hd__clkbuf_16 -buf_list sky130_fd_sc_hd__clkbuf_4

puts "==== 9. Global and Detailed Routing ===="
# Fix for ORD-0305: Ensure nets aren't incorrectly typed as POWER
# Using the OpenDB (odb) low-level API for maximum compatibility
set db_block [ord::get_db_block]
foreach net [$db_block getNets] {
    if {[$net getName] == "one_" || [$net getName] == "zero_"} {
        $net setSigType SIGNAL
    }
}
global_route
detailed_route

puts "==== 10. Exporting Final Layout ===="
write_def build/riscv_core_top.def

puts "==== 🎉 BARE-METAL PHYSICAL DESIGN COMPLETED 🎉 ===="
puts "==== Open build/riscv_core_top.def in KLayout to view the layout ===="
