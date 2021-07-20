#include "stdio.h"
#include "stdbool.h"
#include "fidget.h"

void main(){
    // fidget_call_me_maybe("+9 360872 1222");
    // printf("%s\n", fidget_flight_club_rule(2));
    // printf("%s\n", fidget_input_code(1, 2, 3, 4) ? "True" : "False");
    // printf("%s\n", fidget_node_get_name(1));

    // fidget_start_fidget(
    //     "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
    //     "Fidget",
    //     "WelcomeFrame",
    //     false
    // );

    Node n = fidget_create_node();
    printf("n.ref %d\n", (long long)n);
    fidget_set_node_count(n, 123);
    printf("n.count %d\n", fidget_get_node_count(n));

    Vec2 a;
    a.x = 1;
    a.y = 2;
    fidget_give_vec(a);
    Vec2 v = fidget_take_vec();
    printf("%f %f\n", v.x, v.y);

}
