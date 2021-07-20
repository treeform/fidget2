#include <stdbool.h>
bool fidget_test_numbers(char a, unsigned char b, short c, unsigned short d, int e, unsigned int f, long long g, unsigned long long h, long long i, unsigned long long j, float k, double l, double m);

typedef long long Node;
char* fidget_get_node_name(Node node);
void fidget_set_node_name(Node node, char* name);
long long fidget_get_node_count(Node node);
void fidget_set_node_count(Node node, long long count);

Node fidget_create_node();

typedef struct Vec2 {
  float x;
  float y;
} Vec2;

void fidget_give_vec(Vec2 v);
Vec2 fidget_take_vec();
