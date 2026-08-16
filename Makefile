fma_core:
	iverilog -g2012 -s bf16_fma_core_tb \
		-o sim/fma_core_tb \
		rtl/bf16_decode_classify.sv \
		rtl/bf16_multiplier.sv \
		rtl/bf16_aligner.sv \
		rtl/bf16_addsub.sv \
		rtl/bf16_normalizer.sv \
		rtl/bf16_rounder.sv \
		rtl/bf16_fma_core.sv \
		tb/bf16_fma_core_tb.sv
	vvp sim/fma_core_tb

decode_classify:
	iverilog -g2012 -s bf16_decode_classify_tb \
		-o sim/decode_classify_tb \
		rtl/bf16_decode_classify.sv \
		tb/bf16_decode_classify_tb.sv
	vvp sim/decode_classify_tb

multiplier:
	iverilog -g2012 -s bf16_multiplier_tb \
		-o sim/multiplier_tb \
		rtl/bf16_decode_classify.sv \
		rtl/bf16_multiplier.sv \
		tb/bf16_multiplier_tb.sv
	vvp sim/multiplier_tb

aligner:
	iverilog -g2012 -s bf16_aligner_tb \
		-o sim/aligner_tb \
		rtl/bf16_aligner.sv \
		tb/bf16_aligner_tb.sv
	vvp sim/aligner_tb

addsub:
	iverilog -g2012 -s bf16_addsub_tb \
		-o sim/addsub_tb \
		rtl/bf16_addsub.sv \
		tb/bf16_addsub_tb.sv
	vvp sim/addsub_tb

normalizer:
	iverilog -g2012 -s bf16_normalizer_tb \
		-o sim/normalizer_tb \
		rtl/bf16_normalizer.sv \
		tb/bf16_normalizer_tb.sv
	vvp sim/normalizer_tb

rounder:
	iverilog -g2012 -s bf16_rounder_tb \
		-o sim/rounder_tb \
		rtl/bf16_rounder.sv \
		tb/bf16_rounder_tb.sv
	vvp sim/rounder_tb

loader:
	iverilog -g2012 -s bf16_loader_tb \
		-o sim/loader_tb \
		rtl/bf16_loader.sv \
		tb/bf16_loader_tb.sv
	vvp sim/loader_tb

outputter:
	iverilog -g2012 -s bf16_outputter_tb \
		-o sim/outputter_tb \
		rtl/bf16_outputter.sv \
		tb/bf16_outputter_tb.sv
	vvp sim/outputter_tb

fma_io:
	iverilog -g2012 -s bf16_fma_io_tb \
		-o sim/fma_io_tb \
		rtl/bf16_loader.sv \
		rtl/bf16_outputter.sv \
		rtl/bf16_fma_io.sv \
		tb/bf16_fma_io_tb.sv
	vvp sim/fma_io_tb

fma:
	iverilog -g2012 -s bf16_fma_tb \
		-o sim/fma_tb \
		rtl/bf16_decode_classify.sv \
		rtl/bf16_multiplier.sv \
		rtl/bf16_aligner.sv \
		rtl/bf16_addsub.sv \
		rtl/bf16_normalizer.sv \
		rtl/bf16_rounder.sv \
		rtl/bf16_fma_core.sv \
		rtl/bf16_loader.sv \
		rtl/bf16_outputter.sv \
		rtl/bf16_fma_io.sv \
		rtl/bf16_fma.sv \
		tb/bf16_fma_tb.sv
	vvp sim/fma_tb

vectors:
	python3 scripts/generate_vectors.py

TESTS = decode_classify multiplier aligner addsub normalizer rounder \
	fma_core loader outputter fma_io fma

test:
	@status=0; \
	for test in $(TESTS); do \
		if $(MAKE) $$test > sim/$$test.log 2>&1; then \
			summary=$$(grep "TB: PASS" sim/$$test.log | tail -1); \
			prefix=$${summary%%PASS*}; \
			suffix=$${summary#*PASS}; \
			printf "%s\033[32mPASS\033[0m%s\n" "$$prefix" "$$suffix"; \
		else \
			summary=$$(grep "TB: FAIL" sim/$$test.log | tail -1); \
			prefix=$${summary%%FAIL*}; \
			suffix=$${summary#*FAIL}; \
			printf "%s\033[31mFAIL\033[0m%s\n" "$$prefix" "$$suffix"; \
			status=1; \
		fi; \
	done; \
	exit $$status
