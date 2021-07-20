#include "stdio.h"
#include "stdbool.h"
#include "fidget.h"

void c_cb(){
    printf("in c_cb\n");
}

int count;
void click_cb(){
    count ++;
    char countStr[20];
    snprintf(countStr, 20, "%i", count);

    Node n = fidget_find_node("CounterFrame/CounterDisplay/text");
    fidget_node_set_characters(n, countStr);
    fidget_node_set_dirty(n, true);

    printf("in click_cb\n");
}

void main(){
    // Test function calling
    fidget_call_me_maybe("+9 360872 1222");
    printf("%s\n", fidget_flight_club_rule(2));
    printf("%s\n", fidget_input_code(1, 2, 3, 4) ? "True" : "False");

    printf("%s\n", fidget_test_numbers(
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
    ) ? "True" : "False");

    // Test ref objects
    Fod fod = fidget_create_fod();
    printf("n.ref %d\n", (long long)fod);
    fidget_fod_set_count(fod, 123);
    printf("n.count %d\n", fidget_fod_get_count(fod));

    // Test objects
    Vector2 a;
    a.x = 1;
    a.y = 2;
    fidget_give_vec(a);
    Vector2 v = fidget_take_vec();
    printf("%f %f\n", v.x, v.y);

    // Test enums
    printf("%d\n", fidget_repeat_enum(asRight));

    // Test callbacks
    fidget_call_me_back(c_cb);

    // Test Fidget
    count = 0;
    fidget_on_click_global(click_cb);
    fidget_start_fidget(
        "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
        "C Counter",
        "CounterFrame",
        false
    );
}
