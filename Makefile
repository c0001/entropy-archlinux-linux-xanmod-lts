.PHONY: clean
clean:
	@bash -c "set -e; if [ -d .git ]      ; \
		then echo 'In-git-mode'       ; \
			git reset --hard HEAD ; \
			git clean -xfd .      ; \
		else \
			echo 'In-nongit-mode' ; \
			rm -vf *.pkg.tar.zst  ; \
			rm -vrf src pkg       ; \
		fi"

.PHONY: test
test:
	@bash Make.sh --test

.PHONY: build/stock
build/stock: clean
	@bash Make.sh

.PHONY: build/stock/intel/tigerlake
build/stock/intel/tigerlake: clean
	@bash Make.sh -a 33
