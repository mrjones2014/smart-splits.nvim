import re

from kittens.tui.handler import result_handler
from kitty.key_encoding import KeyEvent, parse_shortcut


def is_window_vim(window, vim_id):
    from kittens.tui.loop import debug
    debug(vim_id)
    fp = window.child.foreground_processes
    return any(re.search(vim_id, p['cmdline'][0] if len(p['cmdline']) else '', re.I) for p in fp)


def encode_key_mapping(window, key_mapping):
    mods, key = parse_shortcut(key_mapping)
    event = KeyEvent(
        mods=mods,
        key=key,
        shift=bool(mods & 1),
        alt=bool(mods & 2),
        ctrl=bool(mods & 4),
        super=bool(mods & 8),
        hyper=bool(mods & 16),
        meta=bool(mods & 32),
    ).as_window_system_event()

    return window.encoded_key(event)

def relative_resize_window(direction, amount, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return

    neighbors = boss.active_tab.current_layout.neighbors_for_window(window, boss.active_tab.windows)
    current_window_id = boss.active_tab.active_window

    left_neighbors = neighbors.get('left')
    right_neighbors = neighbors.get('right')
    top_neighbors = neighbors.get('top')
    bottom_neighbors = neighbors.get('bottom')

    # has a neighbor on both sides
    if direction == 'left' and (left_neighbors and right_neighbors):
        boss.active_tab.resize_window('narrower', amount)
    # only has left neighbor
    elif direction == 'left' and left_neighbors:
        boss.active_tab.resize_window('wider', amount)
    # only has right neighbor
    elif direction == 'left' and right_neighbors:
        boss.active_tab.resize_window('narrower', amount)

    # has a neighbor on both sides
    elif direction == 'right' and (left_neighbors and right_neighbors):
        boss.active_tab.resize_window('wider', amount)
    # only has left neighbor
    elif direction == 'right' and left_neighbors:
        boss.active_tab.resize_window('narrower', amount)
    # only has right neighbor
    elif direction == 'right' and right_neighbors:
        boss.active_tab.resize_window('wider', amount)

    # has a neighbor above and below
    elif direction == 'up' and (top_neighbors and bottom_neighbors):
        boss.active_tab.resize_window('shorter', amount)
    # only has top neighbor
    elif direction == 'up' and top_neighbors:
        boss.active_tab.resize_window('taller', amount)
    # only has bottom neighbor
    elif direction == 'up' and bottom_neighbors:
        boss.active_tab.resize_window('shorter', amount)

    # has a neighbor above and below
    elif direction == 'down' and (top_neighbors and bottom_neighbors):
        boss.active_tab.resize_window('taller', amount)
    # only has top neighbor
    elif direction == 'down' and top_neighbors:
        boss.active_tab.resize_window('shorter', amount)
    # only has bottom neighbor
    elif direction == 'down' and bottom_neighbors:
        boss.active_tab.resize_window('taller', amount)


def main():
    pass


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    action = args[1]
    direction = args[2]
    key_mapping = args[3] if action == 'neighboring_window' else args[4]
    amount = int(args[3]) if action == 'relative_resize' else None
    vim_id_idx = 4 if action == 'neighboring_window' else 5
    vim_id = args[vim_id_idx] if len(args) > vim_id_idx else "n?vim"

    if window is None:
        return
    if is_window_vim(window, vim_id):
        for keymap in key_mapping.split(">"):
            encoded = encode_key_mapping(window, keymap)
            window.write_to_child(encoded)
    elif action == 'neighboring_window':
        boss.active_tab.neighboring_window(direction)
    elif action == 'relative_resize':
        relative_resize_window(direction, amount, target_window_id, boss)
