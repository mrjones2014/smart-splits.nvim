def main():
    pass


def handle_result(args, result, target_window_id, boss):
    boss.active_tab.neighboring_window(args[1])


handle_result.no_ui = True
