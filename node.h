#ifndef NODE_H
#define NODE_H

typedef struct Node {
    char        *label;   /* text label for this node    */
    struct Node *left;    /* first child                 */
    struct Node *right;   /* second child / next sibling */
} Node;

/* Allocate a new node; label is copied internally. */
Node *makeNode(const char *label, Node *left, Node *right);

/* Recursively free the entire subtree. */
void  freeTree(Node *n);

/* Write a Graphviz DOT file for the tree rooted at root. */
void  writeDotFile(Node *root, const char *filename);

#endif /* NODE_H */
