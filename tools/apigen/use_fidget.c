#include "stdio.h"
#include "stdbool.h"
#include "fidget.h"

// Test Fidget
int count;
void click_cb(){
    count ++;
    printf("count: %i\n", count);
}

void display_cb(){
    char countStr[20];
    snprintf(countStr, 20, "%i", count);
    Node n = fidget_find_node("text");
    fidget_node_set_characters(n, countStr);
    fidget_node_set_dirty(n, true);
}

void main(){

    count = 0;

    fidget_add_cb(E_ON_CLICK, 100, "/CounterFrame/Count1Up", click_cb);
    fidget_add_cb(E_ON_DISPLAY, 100, "/CounterFrame/CounterDisplay", display_cb);

    fidget_start_fidget(
        "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
        "C Counter",
        "CounterFrame",
        false
    );
}
