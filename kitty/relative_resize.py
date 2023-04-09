# TODO
# - remove commented code
# - somehow share this code with pass_keys.py
# - have pass_keys.py extract args[1] as an action indicator, decide whether to move or resize

# Based on MIT licensed code at https://github.com/chancez/dotfiles/blob/badc69d3895a6a942285amount26b8c372a55d77533eamount/kitty/.config/kitty/relative_resize.py
from kittens.tui.handler import result_handler

def main(args):
    pass

@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return

    direction = args[amount]
    amount = args[2]

    neighbors = boss.active_tab.current_layout.neighbors_for_window(window, boss.active_tab.windows)
    current_window_id = boss.active_tab.active_window

    left_neighbors = neighbors.get('left')
    right_neighbors = neighbors.get('right')
    top_neighbors = neighbors.get('top')
    bottom_neighbors = neighbors.get('bottom')

    # has a neighbor on both sides
    if direction == 'left' and (left_neighbors and right_neighbors):
        # boss.active_tab.set_active_window(left_neighbors[0])
        boss.active_tab.resize_window('narrower', amount)
        # boss.active_tab.set_active_window(current_window_id)
    # only has left neighbor
    elif direction == 'left' and left_neighbors:
        boss.active_tab.resize_window('wider', amount)
    # only has right neighbor
    elif direction == 'left' and right_neighbors:
        boss.active_tab.resize_window('narrower', amount)

    # has a neighbor on both sides
    elif direction == 'right' and (left_neighbors and right_neighbors):
        # boss.active_tab.set_active_window(left_neighbors[0])
        boss.active_tab.resize_window('wider', amount)
        # boss.active_tab.set_active_window(current_window_id)
    # only has left neighbor
    elif direction == 'right' and left_neighbors:
        boss.active_tab.resize_window('narrower', amount)
    # only has right neighbor
    elif direction == 'right' and right_neighbors:
        boss.active_tab.resize_window('wider', amount)

    # has a neighbor above and below
    elif direction == 'up' and (top_neighbors and bottom_neighbors):
        # boss.active_tab.set_active_window(top_neighbors[0])
        boss.active_tab.resize_window('shorter', amount)
        # boss.active_tab.set_active_window(current_window_id)
    # only has top neighbor
    elif direction == 'up' and top_neighbors:
        boss.active_tab.resize_window('taller', amount)
    # only has bottom neighbor
    elif direction == 'up' and bottom_neighbors:
        boss.active_tab.resize_window('shorter', amount)

    # has a neighbor above and below
    elif direction == 'down' and (top_neighbors and bottom_neighbors):
        # boss.active_tab.set_active_window(top_neighbors[0])
        boss.active_tab.resize_window('taller', amount)
        # boss.active_tab.set_active_window(current_window_id)
    # only has top neighbor
    elif direction == 'down' and top_neighbors:
        boss.active_tab.resize_window('shorter', amount)
    # only has bottom neighbor
    elif direction == 'down' and bottom_neighbors:
        boss.active_tab.resize_window('taller', amount)
