EBIN_DIR=ebin
SOURCE_DIR=src
INCLUDE_DIR=include
ERLC_FLAGS=-W0

compile:
	mkdir -p $(EBIN_DIR)
	erlc -Ddebug +debug_info -I $(INCLUDE_DIR) -o $(EBIN_DIR) $(ERLC_FLAGS) $(SOURCE_DIR)/*.erl

all: compile

clean:
	rm $(EBIN_DIR)/*.beam
	rm erl_crash.*