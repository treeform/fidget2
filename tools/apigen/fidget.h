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
void fidget_take_seq(uint64 s);
uint64 fidget_return_seq();

typedef long long TextCase;
#define TC_NORMAL 0
#define TC_UPPER 1
#define TC_LOWER 2
#define TC_TITLE 3

typedef long long Typeface2;


typedef struct Font2 {
  Typeface2 typeface;
  float size;
  float line_height;
  enum
  tcNormal, tcUpper, tcLower, tcTitle text_case;
  bool underline;
  bool strikethrough;
  bool no_kerning_adjustments;
} Font2;

Font2 fidget_read_font2(char* font_path);
void fidget_on_click_global(proc_cb a);

typedef long long Node;
char* fidget_node_get_name(Node node);
void fidget_node_set_name(Node node, char* name);
char* fidget_node_get_characters(Node node);
void fidget_node_set_characters(Node node, char* characters);
bool fidget_node_get_dirty(Node node);
void fidget_node_set_dirty(Node node, bool dirty);

Node fidget_find_node(char* glob);

typedef long long EventCbKind;
#define E_ON_CLICK 0
#define E_ON_FRAME 1
#define E_ON_EDIT 2
#define E_ON_DISPLAY 3
#define E_ON_FOCUS 4
#define E_ON_UNFOCUS 5
void fidget_add_cb(EventCbKind kind, long long priority, char* glob, proc_cb handler);
void fidget_start_fidget(char* figma_url, char* window_title, char* entry_frame, bool resizable);
