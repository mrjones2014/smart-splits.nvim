from kittens.tui.handler import result_handler
from kitty.key_encoding import KeyEvent, parse_shortcut


def main(args):
    pass


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


def split_window(boss, direction):
    if direction == 'up' or direction == 'down':
        boss.launch('--cwd=current', '--location=hsplit')
    else:
        boss.launch('--cwd=current', '--location=vsplit')

    if direction == 'up' or direction == 'left':
        boss.active_tab.move_window(direction)


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)

    if window is None:
        return

    direction = args[1]
    cmd = window.child.foreground_cmdline[0]
    if cmd == 'tmux':
        keymap = args[2]
        encoded = encode_key_mapping(window, keymap)
        window.write_to_child(encoded)
    else:
        split_window(boss, direction)