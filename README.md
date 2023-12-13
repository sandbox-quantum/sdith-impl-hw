# Introduction

This repository consists of hardware implementation (in progress) of **Syndrome Decoding in the Head (SDitH)** Digital Signature Scheme (https://sdith.org/). 



<!-- This hardware implementation is part of the research work published at **Conference Name**. -->



<!-- # Citation 

We kindly request you to use the following citation if you use our design. 

```
@inproceedings{deshpande2024sdith,
  author={Sanjay Deshpande and James Howe and Dongze Yue and Jakub Szefer},
  title={SDitH in Hardware},
}
``` -->




# 'modules' folder 

The **module** folder consists of our hardware implementation. It contains following subsections:

- **keygen** - contains key generation related verilog files, tcl script, testbench, and a python script for aligning the input to our hardware keygen module
- **sign** - contains signature generaion related verilog files, tcl script, testbench, and a python script for aligning the input to our hardware keygen module
- **verify** - contains signature verification related verilog files, tcl script, testbench, and a python script for aligning the input to our hardware keygen module
- **common** - contains verilog files that are common among key generation, signature generation and signature verification modules


# Makefile

We provide a makefile for easily gathering all files required for a specific target module. 
<!-- The makefile also has capability of simulating the modules using Xilinx Vivado.  -->
<!-- The makefile consists of following targets: -->



- ***build_keygen***: Gathers all verilog files required by the keygen module, tcl scripts and required memory files required for simulating the design, puts them in **keygen** folder inside the **build** folder
- ***build_sign***: Gathers all verilog files required by the sign module, tcl scripts and required memory files required for simulating the design, puts them in **sign** folder inside the **build** folder
- ***build_verify***: Gathers all verilog files required by the verify module, tcl scripts and required memory files required for simulating the design, puts them in **verify** folder inside the **build** folder
- ***run_amd_sim_keygen***: Creates a Xilinx Vivado project and adds the files from build/keygen and simulates the design and generates output for all parameter sets. After simulation, the generated output files are stored in build/keygen/output
- ***run_amd_sim_sign***: Creates a Xilinx Vivado project and adds the files from build/sign and simulates the design and generates output for all parameter sets. We note that our modules are compatible with each other. Hence, the secret key required for the signature generation operation is generated first using **run_xilinx_sim_sign** and then supplied as input to the signature generation module. 
- ***run_amd_sim_verify***: Creates a Xilinx Vivado project and adds the files from build/verify and simulates the design and generates output for all parameter sets. We again note that our modules are compatible with each other. The public key and signature required for simulating the signature verification operation is generated first using **run_xilinx_sim_keygen** and **run_xilinx_sim_sign** and supplied as input to the signature verification module for simulation.

# Requirements

Please note that for running  run_amd_sim_keygen, run_amd_sim_sign, and run_amd_sim_verify you will need AMD (Xilinx) Vivado installed on the machine and added to the path. 

 
