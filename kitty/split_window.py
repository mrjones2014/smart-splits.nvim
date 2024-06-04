from kittens.tui.handler import result_handler


def main(args):
    pass


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
    split_window(boss, direction)
