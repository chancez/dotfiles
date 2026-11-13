# Supplies {custom} in the tab title templates: the active keyboard mode, with
# the step size while resizing.
from kitty.fast_data_types import get_boss


def draw_title(data):
    mode = data.get('keyboard_mode')
    if not mode:
        return ''
    # relative_resize.py keeps its step on boss.
    step = getattr(get_boss(), 'relative_resize_step', None)
    if mode == 'resize' and step is not None:
        return f' [{mode} {step}]'
    return f' [{mode}]'
