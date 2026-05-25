#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/mman.h>

#include "iob_dma.h"
#include "iob_cache_axi_csrs.h"
#include "iob_dma_driver_files.h"
#include "iob_cache_axi_driver_files.h"

#define TEST_PASSED 0
#define TEST_FAILED 1
#define BUF_SIZE 4096

#define RUN_TEST(test_name)                                                    \
  do {                                                                         \
    printf("Running test: %s...\n", #test_name);                               \
    if (test_name() != TEST_PASSED) {                                          \
      printf("Test failed: %s\n", #test_name);                                 \
      return TEST_FAILED;                                                      \
    }                                                                          \
    printf("Test passed: %s\n", #test_name);                                   \
  } while (0)

static uint32_t va_to_pa(void *vaddr) {
  int pagemap_fd = open("/proc/self/pagemap", O_RDONLY);
  if (pagemap_fd < 0) {
    perror("open /proc/self/pagemap");
    return 0;
  }

  uintptr_t vaddr_page = (uintptr_t)vaddr & ~(getpagesize() - 1);
  uintptr_t offset = (uintptr_t)vaddr - vaddr_page;
  uint64_t entry;

  if (lseek(pagemap_fd, (vaddr_page / getpagesize()) * sizeof(entry),
            SEEK_SET) < 0) {
    perror("lseek pagemap");
    close(pagemap_fd);
    return 0;
  }

  if (read(pagemap_fd, &entry, sizeof(entry)) != sizeof(entry)) {
    perror("read pagemap");
    close(pagemap_fd);
    return 0;
  }

  close(pagemap_fd);

  if (!(entry & (1ULL << 63))) {
    fprintf(stderr, "Page not present at %p\n", vaddr);
    return 0;
  }

  uint64_t pfn = entry & ((1ULL << 55) - 1);
  return (uint32_t)(pfn * getpagesize() + offset);
}

static void cpu_cache_flush(void *addr, size_t len) {
  msync(addr, len, MS_SYNC);
  __sync_synchronize();
}

static void print_cache_counters(void) {
  printf("  RW_HIT=%u RW_MISS=%u\n", iob_cache_axi_csrs_get_RW_HIT(),
         iob_cache_axi_csrs_get_RW_MISS());
  printf("  READ_HIT=%u READ_MISS=%u\n", iob_cache_axi_csrs_get_READ_HIT(),
         iob_cache_axi_csrs_get_READ_MISS());
  printf("  WRITE_HIT=%u WRITE_MISS=%u\n", iob_cache_axi_csrs_get_WRITE_HIT(),
         iob_cache_axi_csrs_get_WRITE_MISS());
  printf("  WTB_EMPTY=%u WTB_FULL=%u\n", iob_cache_axi_csrs_get_WTB_EMPTY(),
         iob_cache_axi_csrs_get_WTB_FULL());
}

static void reset_and_invalidate(void) {
  iob_cache_axi_csrs_set_RST_CNTRS(1);
  iob_cache_axi_csrs_set_RST_CNTRS(0);
  iob_cache_axi_csrs_set_INVALIDATE(1);
  iob_cache_axi_csrs_set_INVALIDATE(0);
}

static int dma_read_with_timeout(uint32_t phys_addr, uint32_t nwords) {
  dma_read_transfer(phys_addr, nwords);
  int timeout = 10000000;
  while (dma_read_busy()) {
    if (--timeout == 0) {
      printf("ERROR: DMA read timeout\n");
      return TEST_FAILED;
    }
  }
  return TEST_PASSED;
}

static int dma_write_with_timeout(uint32_t phys_addr, uint32_t nwords) {
  dma_write_transfer(phys_addr, nwords);
  int timeout = 10000000;
  while (dma_write_busy()) {
    if (--timeout == 0) {
      printf("ERROR: DMA write timeout\n");
      return TEST_FAILED;
    }
  }
  return TEST_PASSED;
}

int test_cache_dma_loopback(void) {
  printf("\n--- Cache DMA Loopback Test ---\n");

  void *src_buf = mmap(NULL, BUF_SIZE, PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  void *dst_buf = mmap(NULL, BUF_SIZE, PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);

  if (src_buf == MAP_FAILED || dst_buf == MAP_FAILED) {
    perror("mmap");
    return TEST_FAILED;
  }

  mlock(src_buf, BUF_SIZE);
  mlock(dst_buf, BUF_SIZE);

  uint32_t src_pa = va_to_pa(src_buf);
  uint32_t dst_pa = va_to_pa(dst_buf);

  if (src_pa == 0 || dst_pa == 0) {
    printf("ERROR: failed to get physical address\n");
    return TEST_FAILED;
  }

  printf("src_virt=%p src_phys=0x%08x\n", src_buf, src_pa);
  printf("dst_virt=%p dst_phys=0x%08x\n", dst_buf, dst_pa);
  printf("DMA version: 0x%06x\n", iob_dma_csrs_get_version());
  printf("Cache version: 0x%06x\n", iob_cache_axi_csrs_get_version());

  reset_and_invalidate();

  uint32_t pattern[4] = {0xDEADBEEF, 0xCAFEBABE, 0x12345678, 0x87654321};
  memcpy(src_buf, pattern, sizeof(pattern));
  cpu_cache_flush(src_buf, sizeof(pattern));

  printf("Source: %08x %08x %08x %08x\n", ((uint32_t *)src_buf)[0],
         ((uint32_t *)src_buf)[1], ((uint32_t *)src_buf)[2],
         ((uint32_t *)src_buf)[3]);

  if (dma_read_with_timeout(src_pa, 4) != TEST_PASSED)
    return TEST_FAILED;

  usleep(1000);

  if (dma_write_with_timeout(dst_pa, 4) != TEST_PASSED)
    return TEST_FAILED;

  cpu_cache_flush(dst_buf, sizeof(pattern));

  printf("Dest:   %08x %08x %08x %08x\n", ((uint32_t *)dst_buf)[0],
         ((uint32_t *)dst_buf)[1], ((uint32_t *)dst_buf)[2],
         ((uint32_t *)dst_buf)[3]);

  int pass = 1;
  for (int i = 0; i < 4; i++) {
    if (pattern[i] != ((uint32_t *)dst_buf)[i]) {
      printf("Mismatch [%d]: sent %08x, got %08x\n", i, pattern[i],
             ((uint32_t *)dst_buf)[i]);
      pass = 0;
    }
  }

  if (pass)
    printf("Cache DMA loopback: PASSED\n");
  else
    printf("Cache DMA loopback: FAILED\n");

  print_cache_counters();

  munmap(src_buf, BUF_SIZE);
  munmap(dst_buf, BUF_SIZE);

  return pass ? TEST_PASSED : TEST_FAILED;
}

int test_cache_counters_via_dma(void) {
  printf("\n--- Cache Counter Test ---\n");

  void *buf = mmap(NULL, BUF_SIZE, PROT_READ | PROT_WRITE,
                   MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (buf == MAP_FAILED) {
    perror("mmap");
    return TEST_FAILED;
  }

  mlock(buf, BUF_SIZE);
  uint32_t buf_pa = va_to_pa(buf);
  if (buf_pa == 0) {
    printf("ERROR: failed to get physical address\n");
    return TEST_FAILED;
  }

  ((uint32_t *)buf)[0] = 0xA5A5A5A5;
  ((uint32_t *)buf)[1] = 0x5A5A5A5A;
  cpu_cache_flush(buf, BUF_SIZE);

  // Test 1: Cold DMA read
  printf("Test 1: DMA read (cold)...\n");
  reset_and_invalidate();
  if (dma_read_with_timeout(buf_pa, 1) != TEST_PASSED)
    return TEST_FAILED;
  printf("  READ_MISS=%u READ_HIT=%u\n", iob_cache_axi_csrs_get_READ_MISS(),
         iob_cache_axi_csrs_get_READ_HIT());

  // Test 2: Warm DMA read (same address)
  printf("Test 2: DMA read (warm)...\n");
  if (dma_read_with_timeout(buf_pa, 1) != TEST_PASSED)
    return TEST_FAILED;
  printf("  READ_MISS=%u READ_HIT=%u\n", iob_cache_axi_csrs_get_READ_MISS(),
         iob_cache_axi_csrs_get_READ_HIT());

  // Test 3: Warm DMA write (same line cached from test 1-2)
  printf("Test 3: DMA write (warm)...\n");
  if (dma_write_with_timeout(buf_pa + 4, 1) != TEST_PASSED)
    return TEST_FAILED;
  printf("  WRITE_MISS=%u WRITE_HIT=%u\n", iob_cache_axi_csrs_get_WRITE_MISS(),
         iob_cache_axi_csrs_get_WRITE_HIT());

  // Test 4: Cold DMA write with WTB probe
  printf("Test 4: DMA write (cold)...\n");
  iob_cache_axi_csrs_set_INVALIDATE(1);
  iob_cache_axi_csrs_set_INVALIDATE(0);
  dma_write_transfer(buf_pa + 4, 1);
  // Under linux, (unlike in baremetal) this print is not fast enough to catch a
  // non empty WTB. The write has already finished, and the buffer is empty.
  // printf("  (during write) WTB_EMPTY=%u WTB_FULL=%u\n",
  //       iob_cache_axi_csrs_get_WTB_EMPTY(),
  //       iob_cache_axi_csrs_get_WTB_FULL());
  while (dma_write_busy())
    ;
  printf("  WRITE_MISS=%u WRITE_HIT=%u\n", iob_cache_axi_csrs_get_WRITE_MISS(),
         iob_cache_axi_csrs_get_WRITE_HIT());

  // Test 5: Status registers
  printf("Test 5: Status registers...\n");
  printf("  WTB_EMPTY=%u WTB_FULL=%u\n", iob_cache_axi_csrs_get_WTB_EMPTY(),
         iob_cache_axi_csrs_get_WTB_FULL());
  printf("  RW_HIT=%u RW_MISS=%u\n", iob_cache_axi_csrs_get_RW_HIT(),
         iob_cache_axi_csrs_get_RW_MISS());
  printf("  READ_HIT=%u READ_MISS=%u\n", iob_cache_axi_csrs_get_READ_HIT(),
         iob_cache_axi_csrs_get_READ_MISS());
  printf("  WRITE_HIT=%u WRITE_MISS=%u\n", iob_cache_axi_csrs_get_WRITE_HIT(),
         iob_cache_axi_csrs_get_WRITE_MISS());
  printf("  Version=0x%06x\n", iob_cache_axi_csrs_get_version());
  printf("Cache counter test complete.\n");

  munmap(buf, BUF_SIZE);
  return TEST_PASSED;
}

int main(void) {
  iob_dma_csrs_init_baseaddr(0);
  iob_cache_axi_csrs_init_baseaddr(0);

  RUN_TEST(test_cache_dma_loopback);
  RUN_TEST(test_cache_counters_via_dma);

  printf("\nAll tests passed!\n");
  return 0;
}
