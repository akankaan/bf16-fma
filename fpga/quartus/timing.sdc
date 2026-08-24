
# Pi clock constraint 
create_clock \
	-name pi_clk \
	-period 10.000 \
	[get_ports {GPIO_1[0]}]
	
derive_clock_uncertainty

# Input and output pins
set pi_inputs [get_ports {
	GPIO_1[1]
	GPIO_1[2]
	GPIO_1[3]
	GPIO_1[4]
	GPIO_1[5]
	GPIO_1[6]
	GPIO_1[7]
	GPIO_1[8]
	GPIO_1[9]
	GPIO_1[10]
	GPIO_1[11]
	GPIO_1[12]
	GPIO_1[13]
	GPIO_1[14]
	GPIO_1[15]
	GPIO_1[16]
	GPIO_1[17]
	GPIO_1[18]
}]

set pi_outputs [get_ports {
	GPIO_1[19]
	GPIO_1[20]
	GPIO_1[21]
	GPIO_1[22]
	GPIO_1[23]
	GPIO_1[24]
	GPIO_1[25]
	GPIO_1[26]
	GPIO_1[27]
}]

# Input and output delays
set_input_delay -clock pi_clk -max 1.000 $pi_inputs
set_input_delay -clock pi_clk -min 0.000 $pi_inputs

set_output_delay -clock pi_clk -max 1.000 $pi_outputs
set_output_delay -clock pi_clk -min 0.000 $pi_outputs