#include <errno.h>
#include <gpiod.h>
#include <stdint.h>
#include <stdio.h>
#include <time.h>

// Raspberry Pi BCM GPIO pin numbers
#define PIN_CLK           4
#define PIN_RST_N        17
#define PIN_IN_VALID     27
#define PIN_RESULT_VALID 26

#define GPIO_CHIP_NAME        "gpiochip0"
#define PI_TO_FPGA_PIN_COUNT  19
#define FPGA_TO_PI_PIN_COUNT   9

#define HALF_CLOCK_NS 10000L

// Input data pins listed from bit 0 to bit 15
static const unsigned int PIN_IN_DATA[16] = {
     0,  1,  2,  3,  5,  6,  7,  8,
     9, 10, 11, 12, 13, 14, 15, 16
};

// Output data pins listed from bit 0 to bit 7
static const unsigned int PIN_OUT_DATA[8] = {
    18, 19, 20, 21, 22, 23, 24, 25
};

static struct gpiod_chip *gpio_chip;
static struct gpiod_line_bulk pi_to_fpga_lines = GPIOD_LINE_BULK_INITIALIZER;
static struct gpiod_line_bulk fpga_to_pi_lines = GPIOD_LINE_BULK_INITIALIZER;
static int pi_to_fpga_requested;
static int fpga_to_pi_requested;

static int gpio_init(void);
static void gpio_cleanup(void);

static int write_fpga_inputs(uint16_t in_data, int in_valid, int clk, int rst_n);
static int read_fpga_outputs(uint8_t *out_data, int *result_valid);

static int clock_cycle(uint16_t in_data, int in_valid, int rst_n,
                       uint8_t *out_data, int *result_valid);

static int reset_fma(void);

static int gpio_init(void)
{
    unsigned int pi_to_fpga_pins[PI_TO_FPGA_PIN_COUNT] = {
        PIN_CLK, PIN_RST_N, PIN_IN_VALID
    };
    unsigned int fpga_to_pi_pins[FPGA_TO_PI_PIN_COUNT];
    int initial_values[PI_TO_FPGA_PIN_COUNT] = {0};

    for (int i = 0; i < 16; i++) {
        pi_to_fpga_pins[i + 3] = PIN_IN_DATA[i];
    }

    for (int i = 0; i < 8; i++) {
        fpga_to_pi_pins[i] = PIN_OUT_DATA[i];
    }
    fpga_to_pi_pins[8] = PIN_RESULT_VALID;

    gpio_chip = gpiod_chip_open_by_name(GPIO_CHIP_NAME);
    if (gpio_chip == NULL) {
        perror("gpiod_chip_open_by_name");
        return -1;
    }

    if (gpiod_chip_get_lines(gpio_chip, pi_to_fpga_pins,
                             PI_TO_FPGA_PIN_COUNT,
                             &pi_to_fpga_lines) < 0) {
        perror("gpiod_chip_get_lines for Pi outputs");
        gpio_cleanup();
        return -1;
    }

    if (gpiod_line_request_bulk_output(&pi_to_fpga_lines, "bf16-fma",
                                       initial_values) < 0) {
        perror("gpiod_line_request_bulk_output");
        gpio_cleanup();
        return -1;
    }
    pi_to_fpga_requested = 1;

    if (gpiod_chip_get_lines(gpio_chip, fpga_to_pi_pins,
                             FPGA_TO_PI_PIN_COUNT,
                             &fpga_to_pi_lines) < 0) {
        perror("gpiod_chip_get_lines for Pi inputs");
        gpio_cleanup();
        return -1;
    }

    if (gpiod_line_request_bulk_input(&fpga_to_pi_lines, "bf16-fma") < 0) {
        perror("gpiod_line_request_bulk_input");
        gpio_cleanup();
        return -1;
    }
    fpga_to_pi_requested = 1;

    return 0;
}

static void gpio_cleanup(void)
{
    if (fpga_to_pi_requested) {
        gpiod_line_release_bulk(&fpga_to_pi_lines);
        fpga_to_pi_requested = 0;
    }

    if (pi_to_fpga_requested) {
        gpiod_line_release_bulk(&pi_to_fpga_lines);
        pi_to_fpga_requested = 0;
    }

    if (gpio_chip != NULL) {
        gpiod_chip_close(gpio_chip);
        gpio_chip = NULL;
    }
}

static int write_fpga_inputs(uint16_t in_data, int in_valid, int clk, int rst_n)
{
    int values[PI_TO_FPGA_PIN_COUNT];

    if (!pi_to_fpga_requested) {
        errno = ENODEV;
        perror("write_fpga_inputs");
        return -1;
    }

    values[0] = clk;
    values[1] = rst_n;
    values[2] = in_valid;

    for (int i = 0; i < 16; i++) {
        values[i + 3] = (in_data >> i) & 1u;
    }

    if (gpiod_line_set_value_bulk(&pi_to_fpga_lines, values) < 0) {
        perror("gpiod_line_set_value_bulk");
        return -1;
    }

    return 0;
}

static int read_fpga_outputs(uint8_t *out_data, int *result_valid)
{
    int values[FPGA_TO_PI_PIN_COUNT];
    uint8_t result = 0;

    if ((out_data == NULL) || (result_valid == NULL)) {
        errno = EINVAL;
        perror("read_fpga_outputs");
        return -1;
    }

    if (!fpga_to_pi_requested) {
        errno = ENODEV;
        perror("read_fpga_outputs");
        return -1;
    }

    if (gpiod_line_get_value_bulk(&fpga_to_pi_lines, values) < 0) {
        perror("gpiod_line_get_value_bulk");
        return -1;
    }

    for (int i = 0; i < 8; i++) {
        result |= (uint8_t)(values[i] << i);
    }

    *out_data = result;
    *result_valid = values[8];

    return 0;
}

static int clock_cycle(uint16_t in_data, int in_valid, int rst_n,
                       uint8_t *out_data, int *result_valid)
{
    const struct timespec half_clock = {0, HALF_CLOCK_NS};

    // Drive inputs while the clock is low
    if (write_fpga_inputs(in_data, in_valid, 0, rst_n) < 0) {
        return -1;
    }
    nanosleep(&half_clock, NULL);

    // Raise the clock so the FPGA samples the inputs
    if (write_fpga_inputs(in_data, in_valid, 1, rst_n) < 0) {
        return -1;
    }
    nanosleep(&half_clock, NULL);

    // Read any output produced by this clock edge
    if (read_fpga_outputs(out_data, result_valid) < 0) {
        return -1;
    }

    // Return the clock low
    return write_fpga_inputs(in_data, in_valid, 0, rst_n);
}

static int reset_fma(void)
{
    uint8_t out_data;
    int result_valid;

    // Reset for two rising edges
    if (clock_cycle(0, 0, 0, &out_data, &result_valid) < 0) {
        return -1;
    }

    if (clock_cycle(0, 0, 0, &out_data, &result_valid) < 0) {
        return -1;
    }

    // Release reset at negative clock edge
    return write_fpga_inputs(0, 0, 0, 1);
}
