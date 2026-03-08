#!/bin/bash
# Native-like Wrapper for Yosys and OpenROAD

export PDK_ROOT=/Users/vulcan/.ciel
export IMAGE="ghcr.io/the-openroad-project/openlane:ff5509f65b17bfa4068d5336495ab1718987ff69-arm64v8"

echo "==== Running Yosys (Logic Synthesis) ===="
docker run --rm -v $(pwd):/work -v $PDK_ROOT:$PDK_ROOT -e MY_PDK=$PDK_ROOT -w /work $IMAGE yosys -c scripts/synth.tcl

echo "==== Running OpenROAD (Physical Design) ===="
docker run --rm -v $(pwd):/work -v $PDK_ROOT:$PDK_ROOT -e MY_PDK=$PDK_ROOT -w /work $IMAGE openroad -exit scripts/physical_design.tcl

echo "==== Done! ===="
