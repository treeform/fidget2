from fidget import *

# call_me_maybe("+9 360872 1222")
# print(flight_club_rule(2))
# print(input_code(1, 2, 3, 4))
# print(node_get_name(1))

print(test_numbers(
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
))

# start_fidget(
#     "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
#     "Fidget",
#     "WelcomeFrame",
#     False,
# )


n = create_node()
print("n.ref", n.ref)
n.count = 123
print("n.count", n.count)

print(give_vec(Vec2(x = 1, y = 2)))
print(take_vec())
