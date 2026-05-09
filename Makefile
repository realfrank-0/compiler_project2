# ── Makefile ─────────────────────────────────────────────────────
# Builds the flex/bison LL(1) parse-tree compiler.
#
# Tested with:  flex 2.6.x,  bison 3.x,  gcc 11+
#               win_flex_bison 2.5.25 (Windows)
#
# Usage:
#   make            – build the 'parser' executable
#   make run        – parse the sample input string
#   make png        – render the generated DOT file to PNG
#   make tree-png   – render the hand-crafted tree.dot to PNG
#   make clean      – remove generated files
#
# ── Platform detection ───────────────────────────────────────────
# On Linux/macOS the Flex runtime is -lfl (or -ll on some systems).
# On Windows with win_flex_bison the runtime is built into the
# generated lex.yy.c, so NO extra -l flag is needed.
# The block below auto-selects the right flag.

ifeq ($(OS),Windows_NT)
    # win_flex_bison: runtime is self-contained – no extra lib needed
    LDFLAGS =
    FLEX    = win_flex
    BISON   = win_bison
else
    # Linux / macOS: link the Flex runtime
    LDFLAGS = -lfl
    FLEX    = flex
    BISON   = bison
endif

CC      = gcc
CFLAGS  = -Wall -Wextra -g

TARGET  = parser
INPUT   = "id ^ id ^ id ; id ^ id"

.PHONY: all run png tree-png clean

all: $(TARGET)

# ── Generate parser files from Bison ─────────────────────────────
parser.tab.c parser.tab.h: parser.y
	$(BISON) -d parser.y

# ── Generate scanner from Flex ───────────────────────────────────
lex.yy.c: scanner.l parser.tab.h
	$(FLEX) scanner.l

# ── Compile everything ────────────────────────────────────────────
$(TARGET): parser.tab.c lex.yy.c node.c node.h
	$(CC) $(CFLAGS) -o $(TARGET) parser.tab.c lex.yy.c node.c $(LDFLAGS)

# ── Run the parser on the sample string ──────────────────────────
run: $(TARGET)
	echo $(INPUT) | ./$(TARGET)

# ── Render auto-generated DOT → PNG ──────────────────────────────
png: run
	dot -Tpng parse_tree.dot -o parse_tree.png
	@echo "Image written: parse_tree.png"

# ── Render hand-crafted DOT → PNG ────────────────────────────────
tree-png:
	dot -Tpng tree.dot -o tree.png
	@echo "Image written: tree.png"

# ── Clean ─────────────────────────────────────────────────────────
clean:
	rm -f $(TARGET) parser.tab.c parser.tab.h lex.yy.c \
	      parse_tree.dot parse_tree.png tree.png
