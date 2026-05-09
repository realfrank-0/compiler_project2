#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "node.h"

/* ── Node allocation ──────────────────────────────────────────── */

Node *makeNode(const char *label, Node *left, Node *right) {
    Node *n = (Node *)malloc(sizeof(Node));
    if (!n) { fprintf(stderr, "Out of memory\n"); exit(1); }
    n->label = strdup(label);
    if (!n->label) { fprintf(stderr, "Out of memory\n"); exit(1); }
    n->left  = left;
    n->right = right;
    return n;
}

/* ── Tree deallocation ────────────────────────────────────────── */

void freeTree(Node *n) {
    if (!n) return;
    freeTree(n->left);
    freeTree(n->right);
    free(n->label);
    free(n);
}

/* ── DOT Export ───────────────────────────────────────────────── */

/*
 * Classify a node label so we can colour-code the DOT output:
 *   terminal  → blue rectangle
 *   epsilon   → yellow rectangle
 *   non-term  → white circle
 *
 * Terminals in this grammar: "id", "^", ";"
 * Epsilon label used by the parser: the UTF-8 Greek letter ε (0xCE B5)
 *   or the ASCII fallback string "eps".
 */
static int isTerminal(const char *lbl) {
    return (strcmp(lbl, "id") == 0 ||
            strcmp(lbl, "^")  == 0 ||
            strcmp(lbl, ";")  == 0);
}

static int isEpsilon(const char *lbl) {
    /* UTF-8 ε */
    if ((unsigned char)lbl[0] == 0xCE && (unsigned char)lbl[1] == 0xB5) return 1;
    /* ASCII fallback */
    if (strcmp(lbl, "eps") == 0) return 1;
    return 0;
}

/*
 * exportNode – recursive pre-order traversal.
 * We use the binary (left, right) tree as a sibling chain:
 *   node->left  = first child
 *   node->right = next sibling of node (used by caller's loop)
 *
 * For this grammar the tree is built so that:
 *   a node's "children" form a linked list via the right pointer of
 *   each child.  e.g. R has children caret, idNode, R_recursive
 *   stored as:  R->left = caret
 *               caret->right = idNode
 *               idNode->right = R_recursive
 *
 * exportNode emits all children by following the sibling chain.
 */
static void exportNode(Node *n, FILE *f, int *counter, int parentId) {
    if (!n) return;

    int myId = (*counter)++;

    const char *shape = "circle";
    const char *fill  = "\"#FFFFFF\"";

    if (isTerminal(n->label)) {
        shape = "rect";
        fill  = "\"#AED6F1\"";   /* light blue */
    } else if (isEpsilon(n->label)) {
        shape = "rect";
        fill  = "\"#F9E79F\"";   /* yellow */
    }

    fprintf(f, "    n%d [label=\"%s\", shape=%s, style=filled, fillcolor=%s];\n",
            myId, n->label, shape, fill);

    if (parentId >= 0)
        fprintf(f, "    n%d -> n%d;\n", parentId, myId);

    /* Walk all children (stored as a sibling chain under left) */
    Node *child = n->left;
    while (child) {
        Node *nextSibling = child->right;  /* save before exportNode touches it */
        /* Temporarily disconnect sibling so the child's own children
           are accessed via child->left only (right is the sibling link) */
        child->right = NULL;               /* detach sibling */
        exportNode(child, f, counter, myId);
        child->right = nextSibling;        /* restore */
        child = nextSibling;
    }
}

void writeDotFile(Node *root, const char *filename) {
    FILE *f = fopen(filename, "w");
    if (!f) { perror("Cannot open DOT file"); return; }

    fprintf(f, "digraph ParseTree {\n");
    fprintf(f, "    node [fontname=\"Arial\", fontsize=12];\n");
    fprintf(f, "    rankdir=TB;\n\n");

    int counter = 0;
    exportNode(root, f, &counter, -1);

    fprintf(f, "}\n");
    fclose(f);
    printf("DOT file written: %s\n", filename);
}
