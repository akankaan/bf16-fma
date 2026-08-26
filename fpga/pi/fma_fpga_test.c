#include <errno.h>
#include <gpiod.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// Raspberry Pi BCM GPIO pin numbers
#define PIN_CLK           4
#define PIN_RST_N        17
#define PIN_IN_VALID     27
#define PIN_RESULT_VALID 26

#define GPIO_CHIP_PATH        "/dev/gpiochip0"
#define PI_TO_FPGA_PIN_COUNT  19
#define FPGA_TO_PI_PIN_COUNT   9

#define HALF_CLOCK_NS 10000L
#define RESULT_TIMEOUT_CYCLES 32

// Input data pins listed from bit 0 to bit 15
static const unsigned int PIN_IN_DATA[16] = {
     0,  1,  2,  3,  5,  6,  7,  8,
     9, 10, 11, 12, 13, 14, 15, 16
};

// Output data pins listed from bit 0 to bit 7
static const unsigned int PIN_OUT_DATA[8] = {
    18, 19, 20, 21, 22, 23, 24, 25
};

struct fma_vector {
    uint16_t a;
    uint16_t b;
    uint16_t c;
    uint16_t expected;
};

struct output_monitor {
    const struct fma_vector *vectors;
    size_t   vector_count;
    size_t   result_index;
    size_t   errors;
    uint16_t result;
    int      bytes_received;
};

static struct gpiod_chip *gpio_chip;
static struct gpiod_line_request *pi_to_fpga_request;
static struct gpiod_line_request *fpga_to_pi_request;

static int gpio_init(void);
static void gpio_cleanup(void);
static struct gpiod_line_request *request_gpio_lines(
    const unsigned int *pins, size_t pin_count,
    enum gpiod_line_direction direction);

static int write_fpga_inputs(uint16_t in_data, int in_valid, int clk, int rst_n);
static int read_fpga_outputs(uint8_t *out_data, int *result_valid);

static int clock_cycle(uint16_t in_data, int in_valid, int rst_n,
                       uint8_t *out_data, int *result_valid);

static int reset_fma(void);
static int send_transaction(uint16_t a, uint16_t b, uint16_t c,
                            uint8_t out_data[3], int result_valid[3]);

static int load_vectors(const char *path, struct fma_vector **vectors,
                        size_t *vector_count);
static int monitor_output(struct output_monitor *monitor, uint8_t out_data,
                          int result_valid);
static int run_vectors(const char *path);

static struct gpiod_line_request *request_gpio_lines(
    const unsigned int *pins, size_t pin_count,
    enum gpiod_line_direction direction)
{
    struct gpiod_line_settings *settings = NULL;
    struct gpiod_line_config *line_config = NULL;
    struct gpiod_request_config *request_config = NULL;
    struct gpiod_line_request *request = NULL;
    int saved_errno;

    settings = gpiod_line_settings_new();
    line_config = gpiod_line_config_new();
    request_config = gpiod_request_config_new();

    if ((settings == NULL) || (line_config == NULL) ||
        (request_config == NULL)) {
        goto cleanup;
    }

    if (gpiod_line_settings_set_direction(settings, direction) < 0) {
        goto cleanup;
    }

    if ((direction == GPIOD_LINE_DIRECTION_OUTPUT) &&
        (gpiod_line_settings_set_output_value(
             settings, GPIOD_LINE_VALUE_INACTIVE) < 0)) {
        goto cleanup;
    }

    if (gpiod_line_config_add_line_settings(
            line_config, pins, pin_count, settings) < 0) {
        goto cleanup;
    }

    gpiod_request_config_set_consumer(request_config, "bf16-fma");
    request = gpiod_chip_request_lines(
        gpio_chip, request_config, line_config);

cleanup:
    saved_errno = errno;
    if (request_config != NULL) {
        gpiod_request_config_free(request_config);
    }
    if (line_config != NULL) {
        gpiod_line_config_free(line_config);
    }
    if (settings != NULL) {
        gpiod_line_settings_free(settings);
    }
    errno = saved_errno;

    return request;
}

static int gpio_init(void)
{
    unsigned int pi_to_fpga_pins[PI_TO_FPGA_PIN_COUNT] = {
        PIN_CLK, PIN_RST_N, PIN_IN_VALID
    };
    unsigned int fpga_to_pi_pins[FPGA_TO_PI_PIN_COUNT];
    for (int i = 0; i < 16; i++) {
        pi_to_fpga_pins[i + 3] = PIN_IN_DATA[i];
    }

    for (int i = 0; i < 8; i++) {
        fpga_to_pi_pins[i] = PIN_OUT_DATA[i];
    }
    fpga_to_pi_pins[8] = PIN_RESULT_VALID;

    gpio_chip = gpiod_chip_open(GPIO_CHIP_PATH);
    if (gpio_chip == NULL) {
        perror("gpiod_chip_open");
        return -1;
    }

    pi_to_fpga_request = request_gpio_lines(
        pi_to_fpga_pins, PI_TO_FPGA_PIN_COUNT,
        GPIOD_LINE_DIRECTION_OUTPUT);
    if (pi_to_fpga_request == NULL) {
        perror("request Pi output lines");
        gpio_cleanup();
        return -1;
    }

    fpga_to_pi_request = request_gpio_lines(
        fpga_to_pi_pins, FPGA_TO_PI_PIN_COUNT,
        GPIOD_LINE_DIRECTION_INPUT);
    if (fpga_to_pi_request == NULL) {
        perror("request Pi input lines");
        gpio_cleanup();
        return -1;
    }

    return 0;
}

static void gpio_cleanup(void)
{
    if (fpga_to_pi_request != NULL) {
        gpiod_line_request_release(fpga_to_pi_request);
        fpga_to_pi_request = NULL;
    }

    if (pi_to_fpga_request != NULL) {
        gpiod_line_request_release(pi_to_fpga_request);
        pi_to_fpga_request = NULL;
    }

    if (gpio_chip != NULL) {
        gpiod_chip_close(gpio_chip);
        gpio_chip = NULL;
    }
}

static int write_fpga_inputs(uint16_t in_data, int in_valid, int clk, int rst_n)
{
    enum gpiod_line_value values[PI_TO_FPGA_PIN_COUNT];

    if (pi_to_fpga_request == NULL) {
        errno = ENODEV;
        perror("write_fpga_inputs");
        return -1;
    }

    values[0] = clk ? GPIOD_LINE_VALUE_ACTIVE : GPIOD_LINE_VALUE_INACTIVE;
    values[1] = rst_n ? GPIOD_LINE_VALUE_ACTIVE : GPIOD_LINE_VALUE_INACTIVE;
    values[2] = in_valid ? GPIOD_LINE_VALUE_ACTIVE
                         : GPIOD_LINE_VALUE_INACTIVE;

    for (int i = 0; i < 16; i++) {
        values[i + 3] = ((in_data >> i) & 1u)
                            ? GPIOD_LINE_VALUE_ACTIVE
                            : GPIOD_LINE_VALUE_INACTIVE;
    }

    if (gpiod_line_request_set_values(pi_to_fpga_request, values) < 0) {
        perror("gpiod_line_request_set_values");
        return -1;
    }

    return 0;
}

static int read_fpga_outputs(uint8_t* out_data, int* result_valid)
{
    enum gpiod_line_value values[FPGA_TO_PI_PIN_COUNT];
    uint8_t result = 0;

    if ((out_data == NULL) || (result_valid == NULL)) {
        errno = EINVAL;
        perror("read_fpga_outputs");
        return -1;
    }

    if (fpga_to_pi_request == NULL) {
        errno = ENODEV;
        perror("read_fpga_outputs");
        return -1;
    }

    if (gpiod_line_request_get_values(fpga_to_pi_request, values) < 0) {
        perror("gpiod_line_request_get_values");
        return -1;
    }

    for (int i = 0; i < 8; i++) {
        if (values[i] == GPIOD_LINE_VALUE_ACTIVE) {
            result |= (uint8_t)(1u << i);
        }
    }

    *out_data = result;
    *result_valid = values[8] == GPIOD_LINE_VALUE_ACTIVE;

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

static int send_transaction(uint16_t a, uint16_t b, uint16_t c,
                            uint8_t out_data[3], int result_valid[3])
{
    // Load first multiplicand
    if (clock_cycle(a, 1, 1, &out_data[0], &result_valid[0]) < 0) {
        return -1;
    }

    // Load second multiplicand
    if (clock_cycle(b, 1, 1, &out_data[1], &result_valid[1]) < 0) {
        return -1;
    }

    // Load addend
    if (clock_cycle(c, 1, 1, &out_data[2], &result_valid[2]) < 0) {
        return -1;
    }

    // Lower in_valid without generating another rising edge
    return write_fpga_inputs(c, 0, 0, 1);
}

static int load_vectors(const char *path, struct fma_vector **vectors,
                        size_t *vector_count)
{
    FILE *file = fopen(path, "r");
    unsigned int a, b, c, expected;
    size_t count = 0;

    if (file == NULL) {
        perror(path);
        return -1;
    }

    // Vector count pass
    while (fscanf(file, "%x %x %x %x", &a, &b, &c, &expected) == 4) {
        count++;
    }

    if (count == 0) {
        fprintf(stderr, "%s: no vectors found\n", path);
        fclose(file);
        return -1;
    }

    struct fma_vector *loaded_vectors;
    loaded_vectors = malloc(count * sizeof(struct fma_vector));

    if (loaded_vectors == NULL) {
        perror("malloc");
        fclose(file);
        return -1;
    }

    // Second pass writes the inputs and expected results
    rewind(file);

    for (size_t i = 0; i < count; i++) {
        if (fscanf(file, "%x %x %x %x", &a, &b, &c, &expected) != 4) {
            fprintf(stderr, "%s: failed to read vector %zu\n", path, i);
            free(loaded_vectors);
            fclose(file);
            return -1;
        }

        loaded_vectors[i].a = (uint16_t)a;
        loaded_vectors[i].b = (uint16_t)b;
        loaded_vectors[i].c = (uint16_t)c;
        loaded_vectors[i].expected = (uint16_t)expected;
    }

    fclose(file);

    *vectors      = loaded_vectors;
    *vector_count = count;

    return 0;
}

static int monitor_output(struct output_monitor *monitor, uint8_t out_data,
                          int result_valid)
{
    if (!result_valid) {
        return 0;
    }

    if (monitor->bytes_received == 0) {
        monitor->result = out_data;
        monitor->bytes_received = 1;
        return 0;
    }

    monitor->result |= (uint16_t)out_data << 8;

    const struct fma_vector *vector = &monitor->vectors[monitor->result_index];

    if (monitor->result != vector->expected) {
        fprintf(stderr,
                "MISS a=%04x b=%04x c=%04x | got=%04x want=%04x\n",
                (unsigned int)vector->a,
                (unsigned int)vector->b,
                (unsigned int)vector->c,
                (unsigned int)monitor->result,
                (unsigned int)vector->expected);
        monitor->errors++;
    }

    monitor->result_index++;
    monitor->bytes_received = 0;

    return 0;
}

static int run_vectors(const char *path)
{
    struct fma_vector *vectors;
    size_t vector_count;

    if (load_vectors(path, &vectors, &vector_count) < 0) {
        return -1;
    }

    if (reset_fma() < 0) {
        free(vectors);
        return -1;
    }

    struct output_monitor monitor = {
        .vectors = vectors,
        .vector_count = vector_count,
        .result_index = 0,
        .errors = 0,
        .result = 0,
        .bytes_received = 0
    };

    for (size_t i = 0; i < vector_count; i++) {
        uint8_t out_data[3];
        int result_valid[3];

        if (send_transaction(vectors[i].a, vectors[i].b, vectors[i].c,
                             out_data,     result_valid) < 0) {
            free(vectors);
            return -1;
        }

        for (int cycle = 0; cycle < 3; cycle++) {
            if (monitor_output(&monitor, out_data[cycle],
                               result_valid[cycle]) < 0) {
                free(vectors);
                return -1;
            }
        }
    }

    // Drain results
    for (int cycle = 0; (cycle < RESULT_TIMEOUT_CYCLES) &&
                        (monitor.result_index < vector_count);
                         cycle++) {
        uint8_t out_data;
        int result_valid;

        if (clock_cycle(0, 0, 1, &out_data, &result_valid) < 0) {
            free(vectors);
            return -1;
        }

        if (monitor_output(&monitor, out_data, result_valid) < 0) {
            free(vectors);
            return -1;
        }
    }

    if (monitor.result_index < vector_count) {
        size_t missing = vector_count - monitor.result_index;

        fprintf(stderr, "Timed out waiting for %zu FMA result(s)\n", missing);
        monitor.errors += missing;
    }

    printf("%s: %s -- %zu vectors, %zu errors\n",
           path,
           (monitor.errors == 0) ? "PASS" : "FAIL",
           vector_count,
           monitor.errors);

    int status = (monitor.errors == 0) ? 0 : 1;
    free(vectors);

    return status;
}

int main(int argc, char **argv)
{
    if (argc < 2) {
        return 1;
    }

    if (gpio_init() < 0) {
        return 1;
    }

    int status = 0;

    for (int i = 1; i < argc; i++) {
        int result = run_vectors(argv[i]);

        if (result != 0) {
            status = 1;
        }

        if (result < 0) {
            break;
        }
    }

    // Leave the FMA in reset before releasing the GPIOs
    write_fpga_inputs(0, 0, 0, 0);
    gpio_cleanup();

    return status;
}
