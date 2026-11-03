#include <stdio.h>
#include <stdlib.h>
typedef struct Node { struct Node *l, *r; } Node;
static Node *make(int d) { Node *n = malloc(sizeof *n); if (d == 0) { n->l = n->r = 0; } else { n->l = make(d - 1); n->r = make(d - 1); } return n; }
static int check(Node *n) { return n->l ? 1 + check(n->l) + check(n->r) : 1; }
static void drop(Node *n) { if (n->l) { drop(n->l); drop(n->r); } free(n); }
static int one(int d) { Node *t = make(d); int c = check(t); drop(t); return c; }
int main(void) {
    int top = 16, low = 4, stretch = top + 1;
    printf("stretch tree of depth %d check: %d\n", stretch, one(stretch));
    Node *lng = make(top);
    for (int d = low; d <= top; d += 2) { int it = 1 << (top - d + low), s = 0; for (int i = 0; i < it; i++) s += one(d); printf("%d trees of depth %d check: %d\n", it, d, s); }
    printf("long lived tree of depth %d check: %d\n", top, check(lng));
    return 0;
}
