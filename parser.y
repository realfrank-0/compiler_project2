%{
/*
 * parser.y  –  Bison grammar for the LL(1) grammar:
 *
 *   S  → P S'
 *   S' → ; P S' | ε
 *   P  → id R
 *   R  → ^ id R  | ε
 *
 * The parse tree uses the binary Node struct from node.h.
 * Because R → ^ id R has THREE children but Node only has two
 * pointers, we use the RIGHT pointer of each child as a sibling
 * chain (a standard technique for n-ary trees with binary nodes):
 *
 *   node->left        = first child
 *   firstChild->right = second child
 *   secondChild->right= third child
 *   ...
 *   lastChild->right  = NULL
 *
 * For nodes with exactly 2 children the sibling chain is just:
 *   node->left = child1,  child1->right = child2,  child2->right = NULL
 *
 * Helper macros below build these chains cleanly.
 *
 * FIXES over original:
 *   1. yylval.str now set in scanner.l (ID name correctly labelled)
 *   2. No Sp_body / R_body intermediate nodes
 *   3. Epsilon nodes labelled with UTF-8 "ε" (matches tree.dot)
 *   4. freeTree(root) called before exit
 *   5. Removed duplicate makeNode/writeDotFile declarations
 *   6. main() accepts optional filename argument for easier testing
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "node.h"

extern int  yylex(void);
void        yyerror(const char *msg);

Node *root = NULL;   /* root of the parse tree */

/*
 * chain2(a,b)   – make a the first child, b the second sibling
 * chain3(a,b,c) – make a first, b second, c third
 *
 * Because writeDotFile in node.c walks the left/right chain,
 * these macros just wire up the ->right pointers of the children.
 */
static Node *chain2(Node *a, Node *b) {
    a->right = b;
    b->right = NULL;
    return a;          /* returns first child (used as ->left of parent) */
}

static Node *chain3(Node *a, Node *b, Node *c) {
    a->right = b;
    b->right = c;
    c->right = NULL;
    return a;
}

%}

/* ── Semantic value union ─────────────────────────────────────── */
%union {
    char  *str;
    Node  *node;
}

/* ── Token declarations ───────────────────────────────────────── */
%token <str> ID
%token CARET SEMI

/* ── Non-terminal types ───────────────────────────────────────── */
%type  <node> S Sp P R

%%

/* ── Top-level rule ─────────────────────────────────────────────
   Bison is LALR(1); this grammar is also LL(1), so the parse tree
   produced is identical to a hand-traced LL(1) derivation.        */

program
    : S
        {
            root = $1;
            writeDotFile(root, "parse_tree.dot");
            printf("Parse successful. Tree written to parse_tree.dot\n");
        }
    ;

/* ── S → P S' ─────────────────────────────────────────────────── */
S
    : P Sp
        {
            /*  S
                ├── P    (left child, first in chain)
                └── S'   (right of P = second sibling)            */
            $$ = makeNode("S", chain2($1, $2), NULL);
        }
    ;

/* ── S' → ; P S'  |  ε ─────────────────────────────────────────
   Three children: ";"  P  S'  encoded as sibling chain.          */
Sp
    : SEMI P Sp
        {
            Node *semi = makeNode(";",  NULL, NULL);
            /*  S'
                ├── ;    (first child)
                ├── P    (second)
                └── S'   (third)                                   */
            $$ = makeNode("S'", chain3(semi, $2, $3), NULL);
        }
    | /* ε */
        {
            $$ = makeNode("\xce\xb5", NULL, NULL);  /* UTF-8 ε */
        }
    ;

/* ── P → id R ─────────────────────────────────────────────────── */
P
    : ID R
        {
            Node *idNode = makeNode($1, NULL, NULL);
            free($1);   /* $1 was strdup'd by the scanner */
            /*  P
                ├── id   (first child)
                └── R    (second)                                   */
            $$ = makeNode("P", chain2(idNode, $2), NULL);
        }
    ;

/* ── R → ^ id R  |  ε ─────────────────────────────────────────
   Three children: "^"  id  R  encoded as sibling chain.          */
R
    : CARET ID R
        {
            Node *caret  = makeNode("^",  NULL, NULL);
            Node *idNode = makeNode($2,   NULL, NULL);
            free($2);   /* strdup'd by scanner */
            /*  R
                ├── ^    (first child)
                ├── id   (second)
                └── R    (third)                                    */
            $$ = makeNode("R", chain3(caret, idNode, $3), NULL);
        }
    | /* ε */
        {
            $$ = makeNode("\xce\xb5", NULL, NULL);  /* UTF-8 ε */
        }
    ;

%%

/* ── Error handler ──────────────────────────────────────────── */
void yyerror(const char *msg) {
    fprintf(stderr, "Parse error: %s\n", msg);
}

/* ── Entry point ────────────────────────────────────────────── */
int main(int argc, char *argv[]) {
    extern FILE *yyin;

    /* Optional: read from a file passed as argument */
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
        if (!yyin) {
            perror(argv[1]);
            return 1;
        }
    }
    /* Default: read from stdin (pipe or redirect) */

    int result = yyparse();

    if (root) freeTree(root);   /* clean up */

    if (argc == 2 && yyin) fclose(yyin);

    return result;
}
