IP_NAME    = $(shell basename $(shell dirname $(CURDIR)))
RDL_FILE   = $(IP_NAME)_regmap.rdl
GEN_SCRIPT = ../../../../generators/systemrdl/rdl_tools.py

gen:
	python3 $(GEN_SCRIPT) $(RDL_FILE) --output . --python

docs:
	python3 $(GEN_SCRIPT) $(RDL_FILE) --output . --html

clean: clean-docs
	rm -rf $(IP_NAME)_regmap_pkg $(IP_NAME)_regmap*.sv $(IP_NAME)_regmap*.svh

clean-docs:
	rm -rf index.html launcher* data search content css fonts js favicon.png

.PHONY: gen docs clean clean-docs
