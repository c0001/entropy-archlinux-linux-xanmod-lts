.PHONY: clean
clean:
	@if [ -d .git ] ; then          \
		git reset --hard HEAD ; \
		git clean -xfd .      ; \
	fi

.PHONY: test
test:
	@bash Make.sh --test

.PHONY: build/stock
build/stock: clean
	@bash Make.sh

.PHONY: build/stock/intel/tigerlake
build/stock/intel/tigerlake: clean
	@bash Make.sh -a 44
