# Pipelined Bfloat16 Fused Multiply-Add

This project implements a pipelined Bfloat16 Fused Multiply-Add unit. It calculates `a * b + c` without rounding the intermediate product, and then rounds the final result to Bfloat16. The name "fused" comes from combining the multiplication and addition into one operation with one rounding step. This single rounding helps us preserve the product in full intermediate precision and improves the accuracy of the final result. My main motivation for the project was to get more experience with the floating point format and write RTL informed by tapeout flow area and critical path results. 

[![Tests](https://github.com/akankaan/bf16-fma/actions/workflows/test.yml/badge.svg)](https://github.com/akankaan/bf16-fma/actions/workflows/test.yml)

## Project Highlights
- Computes `a * b + c` with only one final rounding step
- Three Bfloat16 operands and a Bfloat16 result
- Six-stage pipelined arithmetic core
- Round-to-nearest, ties-to-even (RNE) rounding
- Implemented in SystemVerilog
- Verified through simulation and formal verification
- Emulated on an FPGA and hardened in SKY130 and submitted through Tiny Tapeout

## Architecture

### Arithmetic Datapath
<!--[Main block diagram]-->

My implementation has six internal pipeline stages to reduce the critical path delay. This was especially useful for the FPGA emulation and the tapeout because their limited I/O requires three clock cycles to load each set of operands. Without pipelining, the clock period would be limited by the delay of the entire arithmetic datapath, meaning that each of these three load cycles would also use the longer clock period. These pipeline stages are:

1) Decode and classify: Extract the sign, exponent, and fraction from each operand while identifying zero, infinity, and NaN special values
2) Multiply: Multiply the significands and calculate product's exponent and sign
3) Align and prepare for addition: Shift the addend based on the exponent difference between the addend and product
4) Add: Add or subtract the aligned magnitudes and determine sum's sign
5) Normalize: Find leading one, shift result to the top of the datapath and adjust its exponent
6) Round: Round the normalized result to Bfloat16 using round-to-nearest, ties-to-even (RNE), and output the final encoded value

The main arithmetic unit is the `fma_core`, and it can also be used as the top instantiated module without the I/O wrapper. Pipeline diagrams and the throughput calculations for both the standalone core and the I/O wrapped unit are below:

<--! draw pipeline diagrams for both core itself and I/O wrapped, calculate throughput for both cases -->

## Numerical Behavior Decisions

- The unit takes in three Bfloat16 number inputs and also outputs in the Bfloat16 format
- Addend is directly added to intermediate product without rounding
- The addend input is Bfloat16 rather than FP32
- Chosen rounding mode is RNE
- Subnormal inputs are considered zero (DAZ) and subnormal outputs are flushed to zero (FTZ)
<!-- !! TODO: No flags etc and other deviations from IEEE 754 !!-->

## Interface and Timing

There are two valid interfaces: one in the arithmetic core and one in the I/O wrapper. 

The arithmetic core takes in `operands_valid` and outputs `fma_result_valid` six cycles later with the calculated result for the valid operand inputs with the pipelining. 

The top level with the I/O wrapper on the other hand has an `in_valid` input for each one of the three 16-bit input cycles. The `loader` raises `operands_valid` high when all three operands are presented and starts the transaction. Once the core finishes the computation, the result is registered and outputted over two 8-bit output cycles in which `result_valid` is high.

<!--! timing diagram for input output loading!!-->

## Tapeout

### Timing-Driven RTL Development
[Explain how reports led to pipeline boundaries, addsub preparation,
hierarchical alignment shifter, etc.]

### Physical Results

<p align="center">
  <img src="docs/bf16_readme_layout.png" width="800" alt="Final routed SKY130 layout of the Bfloat16 FMA">
</p>

<p align="center">
  <em>Final routed SKY130 layout in a 2x2 Tiny Tapeout tile</em>
</p>

The design was hardened for the SKY130 using LibreLane and OpenROAD in a 2x2 Tiny Tapeout tile. The submitted configuration uses a 7.5 ns clock period, corresponding to 133.33 MHz, with closed setup and hold timing across all nine analyzed corners.

| Metric | Result |
| --- | ---: |
| Tiny Tapeout space | 2x2 tile |
| Clock Frequency | 133.33 MHz (7.5 ns) |
| Core area | 72,564.6 µm² |
| Standard-cell area | 42,946.2 µm² |
| Standard-cell utilization | 59.18% |
| Standard and sequential cells | 5,650 and 399 |
| Nominal-corner setup slack | +2.819 ns |
| Worst-corner setup slack | +0.089 ns |
| Worst hold slack | +0.106 ns |
| Estimated nominal power | 13.48 mW |
| DRC, LVS, and antenna violations | 0 |

The worst setup corner was the slow process corner at 100 °C and 1.60 V. The tapeout physical design configuration and layout are available in the [`tt_um_bf16_fma`](https://github.com/akankaan/tt_um_bf16_fma) repository.

### Post-Route Stage Delays

The following table illustrates the critical path across each pipeline stage:

| Stage | Delay | Setup slack |
| --- | ---: | ---: |
| Decode and classify | 2.22 ns | +3.48 ns |
| Multiply | 5.53 ns | +0.09 ns |
| Align and prepare addition | 5.36 ns | +0.20 ns |
| Add/subtract | 4.67 ns | +1.07 ns |
| Normalize | 5.40 ns | +0.22 ns |
| Round and select result | 3.68 ns | +1.85 ns |

The multiplier is the critical stage with the alignment and normalization fairly balanced and not far behind. The input-to-loader path was 1.31 ns, while the longest path through the outputter was 2.58 ns.

The annotated layout below shows how the area breakdown of main RTL modules. The loader, outputter, and pipeline registers are grouped under I/O and pipeline.

![Module area breakdown](docs/bf16_fma_module_breakdown.png)

<p align="center">
  <em>Layout colored by module</em>
</p>

## Verification

### Simulation
- Used exact Python reference model using `Fraction`
- Directed, random, exhaustive-shift, and special-value vectors
- Unit testing for each RTL module along end-to-end `fma` and `fma_core` testbenches
- Further extended random testing with overnight seed sweep testing with 150 different seeds, covering 250M+ random vectors in total

### Formal verification
I wanted to also learn more about formal verification and used SymbiYosys for this purpose. I did formal for the loader, outputter, and combined FMA I/O. Although these modules accept many possible operand and result values, their control behavior depends only on a small internal counter. Keeping the data symbolic allows every value to be checked without exhaustively checking each individually.

I also verified that the aligner's hierarchical shifter produces the same outputs as a simpler behavioral reference.

!! TODO: RTL assertion mention !!

### Hardware Testing on FPGA

I also tested the design on a Terasic DE0-CV with a Cyclone V FPGA. A Raspberry Pi 3 Model A+ is connected directly to the FPGA through GPIO. The Pi drives the input as well as the clock and reset, while the FPGA returns `result_valid` and the result over the 8-bit output.

The C test program on the Pi reads the same FMA vector files used by the RTL simulations. For each vector, it sends `a`, `b`, and `c` over three clock cycles, forms the 16-bit result from the two output bytes, and compares it against the expected value.

![FPGA and Raspberry Pi hardware test setup](docs/bf16_fma_fpga_pi.jpeg)

<p align="center">
  <em>DE0-CV and Raspberry Pi setup used to run FMA test vectors over GPIO</em>
</p>

The Quartus project and pin assignments are in [`fpga/quartus`](fpga/quartus), while the Raspberry Pi test program is in [`fpga/pi`](fpga/pi).  The FPGA resource usage was less than 2%. 

Both the directed tests and all 100,000 random vectors passed on the FPGA with no errors:

<p align="center">
  <img src="docs/bf16_fpga_random_vector.png" width="400" alt="FPGA random-vector test completing with zero errors">
</p>

## Running the Simulations

### Requirements
- Python 3
- Icarus Verilog
- Verilator
- SymbiYosys/OSS CAD Suite for formal verification

### Run the tests

```sh
make vectors
make test
make formal
```
