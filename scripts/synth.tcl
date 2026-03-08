yosys -import

set lib_file "$env(MY_PDK)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

read_verilog OpenLane/designs/riscv_accelerator/src/pc.v \
             OpenLane/designs/riscv_accelerator/src/instruction_memory.v \
             OpenLane/designs/riscv_accelerator/src/register_file.v \
             OpenLane/designs/riscv_accelerator/src/alu.v \
             OpenLane/designs/riscv_accelerator/src/control_unit.v \
             OpenLane/designs/riscv_accelerator/src/mac_unit.v \
             OpenLane/designs/riscv_accelerator/src/convolution_accelerator.v \
             OpenLane/designs/riscv_accelerator/src/custom_instruction_decoder.v \
             OpenLane/designs/riscv_accelerator/src/pipeline_register_if_id.v \
             OpenLane/designs/riscv_accelerator/src/pipeline_register_id_ex.v \
             OpenLane/designs/riscv_accelerator/src/pipeline_register_ex_mem.v \
             OpenLane/designs/riscv_accelerator/src/pipeline_register_mem_wb.v \
             OpenLane/designs/riscv_accelerator/src/riscv_core_top.v

hierarchy -check -top riscv_core_top
synth -top riscv_core_top -flatten

# Logic optimization
opt -full
share -force
fsm
opt -full

# Mapping to Sky130
dfflibmap -liberty $lib_file
abc -liberty $lib_file
opt_clean

write_verilog -noattr build/riscv_core_top_synth.v
stat -liberty $lib_file
