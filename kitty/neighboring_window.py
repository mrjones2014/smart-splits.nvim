from kitty.key_encoding import KeyEvent, parse_shortcut
from kittens.tui.handler import result_handler


def main():
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


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)

    cmd = window.child.foreground_cmdline[0]
    if cmd == 'tmux':
        keymap = args[2]
        encoded = encode_key_mapping(window, keymap)
        window.write_to_child(encoded)
    else:
        boss.active_tab.neighboring_window(args[1])
