from kittens.tui.handler import result_handler

MODE = 'resize'
DEFAULT_STEP = 4
# Shown while the mode is active, so it is obvious keys resize instead of typing.
MODE_COLORS = (
    'active_border_color=#e5c07b',
    'active_tab_background=#e5c07b',
    'active_tab_foreground=#282c34',
)

# direction -> (side whose neighbor the border is shared with, quality to use
# when that neighbor exists, quality when only the opposite neighbor exists)
MOVES = {
    'left': ('right', 'narrower', 'wider'),
    'right': ('right', 'wider', 'narrower'),
    'up': ('bottom', 'shorter', 'taller'),
    'down': ('bottom', 'taller', 'shorter'),
}
OPPOSITE = {'right': 'left', 'bottom': 'top'}


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    action = args[1]
    # boss outlives each kitten run, so the step is kept there.
    step = getattr(boss, 'relative_resize_step', DEFAULT_STEP)

    if action == 'enter':
        boss.relative_resize_step = DEFAULT_STEP
        boss.push_keyboard_mode(MODE)
        boss.combine('set_colors --all --configured ' + ' '.join(MODE_COLORS))
        return
    if action == 'exit':
        boss.pop_keyboard_mode()
        boss.combine('set_colors --all --configured --reset')
        return
    if action in ('bigger', 'smaller'):
        boss.relative_resize_step = step * 2 if action == 'bigger' else max(1, step // 2)
        # The tab title shows the step.
        boss.active_tab_manager.mark_tab_bar_dirty()
        return

    tab = boss.active_tab
    window = tab.active_window
    if window is None:
        return
    neighbors = tab.current_layout.neighbors_for_window(window, tab.windows)
    side, toward, away = MOVES[action]
    if neighbors.get(side):
        tab.resize_window(toward, step)
    elif neighbors.get(OPPOSITE[side]):
        tab.resize_window(away, step)
