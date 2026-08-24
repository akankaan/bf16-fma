// ================================================================
//
// Date  : August 24, 2026
// Author: Kaan Akan
//
// FMA FPGA top level file. Connects to Pi via GPIO pins.
//
// ================================================================


module bf16_fma_fpga_top (

      inout [35:0] GPIO_1

);

	bf16_fma fma 
	(
	
    .clk          (GPIO_1[0]),
    .rst_n        (GPIO_1[1]),
    .in_valid     (GPIO_1[2]),
    .in_data      (GPIO_1[18:3]),
    .out_data     (GPIO_1[26:19]),
    .result_valid (GPIO_1[27])
	);

endmodule 


