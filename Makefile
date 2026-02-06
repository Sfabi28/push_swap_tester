
.PHONY: all

ARGS := $(MAKECMDGOALS)

all:
	@./.launch.sh

ifneq ($(ARGS),)

    $(firstword $(ARGS)):
		@./.launch.sh $(ARGS)

    $(filter-out $(firstword $(ARGS)), $(ARGS)):
		@:

endif
