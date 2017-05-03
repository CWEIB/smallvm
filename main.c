// main.c - Test interpreter.
// John Maloney, April 2017

#include <stdio.h>
#include "mem.h"
#include "interp.h"

void interpTests1(void);
void taskTest(void);

int main(int argc, char *argv[]) {
	printf("Starting...\r\n");
	memInit(5000);

// 	interpTests1();
// 	taskTest();

	while (true) {
		processMessage();
		stepTasks();
	}
	return 0;
}
