CC = riscv64-unknown-linux-gnu-gcc
FLAGS = -Wall -Werror -O2 -static -march=rv32imac -mabi=ilp32
FLAGS += -I../../../src -I../../drivers -DDEV_IF

SRC = iob_cache_dma_test.c
SRC += ../../../src/iob_dma.c
SRC += ../iob_dma_dev_csrs.c
SRC += ../iob_cache_axi_dev_csrs.c

BIN = iob_cache_dma_test

$(BIN): $(SRC)
	$(CC) $(FLAGS) -o $(BIN) $(SRC)

clean:
	rm -f $(BIN)
