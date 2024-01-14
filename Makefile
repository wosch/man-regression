TESTS= basic

all: ${TESTS}

${TESTS}:
	./$@.sh

help:
	@echo "make ${TESTS}"
	@echo "env bug_page_quotes=true man_command=\"sh /usr/src/usr.bin/man/man.sh\" make ${TESTS}"

