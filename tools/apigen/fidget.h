#include <stdbool.h>

typedef void (*proc_cb)();

void fidget_call_me_maybe(char* phone);
char* fidget_flight_club_rule(long long n);
bool fidget_input_code(long long a, long long b, long long c, long long d);
bool fidget_test_numbers(char a, unsigned char b, short c, unsigned short d, int e, unsigned int f, long long g, unsigned long long h, long long i, unsigned long long j, float k, double l, double m);

typedef long long Fod;
char* fidget_fod_get_name(Fod fod);
void fidget_fod_set_name(Fod fod, char* name);
long long fidget_fod_get_count(Fod fod);
void fidget_fod_set_count(Fod fod, long long count);

Fod fidget_create_fod();

typedef struct Vector2 {
  float x;
  float y;
} Vector2;

void fidget_give_vec(Vector2 v);
Vector2 fidget_take_vec();

typedef long long AlignSomething;
#define AS_DEFAULT 0
#define AS_TOP 1
#define AS_BOTTOM 2
#define AS_RIGHT 3
#define AS_LEFT 4
AlignSomething fidget_repeat_enum(AlignSomething e);
void fidget_call_me_back(proc_cb cb);
void fidget_on_click_global(proc_cb a);

typedef long long Node;
char* fidget_node_get_name(Node node);
void fidget_node_set_name(Node node, char* name);
char* fidget_node_get_characters(Node node);
void fidget_node_set_characters(Node node, char* characters);
bool fidget_node_get_dirty(Node node);
void fidget_node_set_dirty(Node node, bool dirty);

Node fidget_find_node(char* glob);
void fidget_start_fidget(char* figma_url, char* window_title, char* entry_frame, bool resizable);
