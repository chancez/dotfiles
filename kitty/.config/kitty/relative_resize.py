from kittens.tui.handler import result_handler

def main(args):
    pass

@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return

    direction = args[1]

    neighbor_direction = direction
    if direction == 'up':
        neighbor_direction = 'top'
    if direction == 'down':
        neighbor_direction = 'bottom'

    has_neighbor = boss.active_tab.neighboring_group_id(neighbor_direction) is not None

    if direction == 'left' or direction == 'right':
        if has_neighbor:
            boss.active_tab.resize_window('wider', 1)
        else:
            boss.active_tab.resize_window('narrower', 1)

    if direction == 'up' or direction == 'down':
        if has_neighbor:
            boss.active_tab.resize_window('taller', 1)
        else:
            boss.active_tab.resize_window('shorter', 1)
