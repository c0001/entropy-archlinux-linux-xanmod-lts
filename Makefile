clean:
	@if [ -d .git ] ; then          \
		git reset --hard HEAD ; \
		git clean -xfd .      ; \
	fi

test:
	@bash Make.sh --test

build_stock: clean
	@bash Make.sh

build_stock_intel_tigerlake:  clean
	@bash Make.sh -a 44
