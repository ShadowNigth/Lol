/* Vaelmoor: compatibilidad con glibc < 2.36.
 * La libstdc++ estática de GCC 12 usa arc4random() (glibc 2.36) si existe al
 * compilar. Definirla aquí (sobre getrandom, glibc 2.25) evita que el binario
 * exija glibc 2.36 y permite ejecutarlo en Ubuntu 22.04 / Linux Mint 21. */
#include <stdint.h>
#include <stdlib.h>
#include <sys/random.h>

uint32_t arc4random(void) {
	uint32_t r = 0;
	if (getrandom(&r, sizeof(r), 0) != (ssize_t)sizeof(r)) {
		r = ((uint32_t)rand() << 16) ^ (uint32_t)rand();
	}
	return r;
}

void arc4random_buf(void *buf, size_t n) {
	unsigned char *p = (unsigned char *)buf;
	while (n > 0) {
		ssize_t got = getrandom(p, n, 0);
		if (got <= 0) {
			for (size_t i = 0; i < n; i++) {
				p[i] = (unsigned char)rand();
			}
			return;
		}
		p += got;
		n -= (size_t)got;
	}
}

uint32_t arc4random_uniform(uint32_t upper_bound) {
	if (upper_bound < 2) {
		return 0;
	}
	uint32_t min = -upper_bound % upper_bound;
	uint32_t r;
	do {
		r = arc4random();
	} while (r < min);
	return r % upper_bound;
}
