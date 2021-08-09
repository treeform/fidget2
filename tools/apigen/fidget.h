#include <stdbool.h>

typedef void (*proc_cb)();

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

