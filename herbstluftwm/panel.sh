#!/bin/bash

        # Layouting
########## ARGS ##########
monitor=${1:-0}

########## OPTIONS ##########
panel_height=15
font="-*-fixed-medium-*-*-*-12-*-*-*-*-*-*-*"
bgcolor=$(herbstclient get frame_border_normal_color)
selbg=$(herbstclient get window_border_active_color)
selfg='#101010'
bordercolor="#26221C"
sep="^bg()^fg($selbg)|"
host=$(hostname)

net_dev="wlan0"

########## VARIABLES ##########
geometry=( $(herbstclient monitor_rect "$monitor") )
if [ -z "$geometry" ] ;then
    echo "Invalid monitor $monitor"
    exit 1
fi
# geometry has the format: WxH+X+Y
x=${geometry[0]}
y=${geometry[1]}
if [[ 0 -eq $monitor ]] && [ $host == "tidus" ]; then
    panel_width=1270
else
    panel_width=${geometry[2]}
fi

# Try to find textwidth binary.
# In e.g. Ubuntu, this is named dzen2-textwidth.
if [ -e "$(which textwidth 2> /dev/null)" ] ; then
    textwidth="textwidth";
elif [ -e "$(which dzen2-textwidth 2> /dev/null)" ] ; then
    textwidth="dzen2-textwidth";
else
    echo "This script requires the textwidth tool of the dzen2 project."
    exit 1
fi

# true if we are using the svn version of dzen2
dzen2_version=$(dzen2 -v 2>&1 | head -n 1 | cut -d , -f 1|cut -d - -f 2)
if [ -z "$dzen2_version" ] ; then
    dzen2_svn="true"
else
    dzen2_svn=""
fi

# Functions
function uniq_linebuffered() {
    awk '$0 != l { print ; l=$0 ; fflush(); }' "$@"
}

########## Widgets ##########
heartbeat_event() {
    count=0
    while true ; do
        echo "heartbeat ${count}"
        count=$((${count} + 1))
        sleep 60 || break
    done
}

# ACPI
acpi_widget() {
    echo $(
        acpi -b |
        awk '{print $3 $4 $5}' |
        sed -e 's/,/ /g' -e 's/^\([A-Z]\)[a-z]*/\1/' -e 's/:[0-9][0-9]$//'
    )
}

# NETWORK
net_widget() {
    ip=$(
        ip address show dev $net_dev |
        grep "scope global" |
        awk '{print $2}' |
        sed 's/\/[0-9]*$//' |
        head -n 1
    )
    ssid=$(
        iwconfig $net_dev |
        grep ESSID |
        sed -e 's_.*ESSID:"\(.*\)"_\1_' |
        head -n 1 |
        awk '{print $1}'
    )
    echo -n "W $ip ($ssid)"
}

volume_widget() {
    dzen_icons="/home/chancez/Pictures/dzen_icons"
    curr_volume=$(echo $volume | cut -d " " -f2)
    if [ "$1" == "toggle" ] && [ "$curr_volume" != "Mute" ]; then
        volume="Mute"
        vol_icon="$dzen_icons/volume_off.xbm"
    else
        volume=$(amixer get Master | grep -Po '\d+\%' | head -1)
        vol_icon="$dzen_icons/volume_on.xbm"
    fi
    echo "^i($vol_icon) $volume"
}


########## Go! ##########
herbstclient pad $monitor $panel_height

{
    # events:
    # Clock
    while true ; do
        date +'date ^fg(#efefef)%H:%M:%S^fg(#909090), %Y-%m-^fg(#efefef)%d'
        sleep 1 || break
    done > >(uniq_linebuffered)  &
    childpid1=$!

    heartbeat_event &
    childpid2=$!

    # hlwm events
    herbstclient --idle

    kill $childpid1 $childpid2

} | tee /dev/stderr | {

    # Processing of events
    TAGS=( $(herbstclient tag_status $monitor) )
    date=""
    windowtitle=""
    acpi=$(acpi_widget)
    ip=$(ip_widget)
    volume=$(volume_widget)

    while true ; do
        # draw tags
        for i in "${TAGS[@]}" ; do
            case ${i:0:1} in
                '#')
                    # Tag is focused, and so is monitor
                    echo -n "^bg($selbg)^fg($selfg)"
                    ;;
                '+')
                    # Tag is focused, but monitor is not
                    echo -n "^bg(#9CA668)^fg(#141414)"
                    ;;
                ':')
                    # Tag is not focused, and is not empty
                    echo -n "^bg()^fg(#ffffff)"
                    ;;
                '!')
                    # The tag contains an urgent window
                    echo -n "^bg(#FF0675)^fg(#141414)"
                    ;;
                *)
                    # Otherwise
                    echo -n "^bg()^fg(#ababab)"
                    ;;
            esac
            # If tag is not empty, show it.
            if [[ "${i:0:1}" != '.' ]]; then
                #echo -n "^ca(1,herbstclient focus_monitor $monitor && herbstclient use ${i:1}) ${i:1} ^ca()"
                echo -n " ${i:1} "
            fi
        done
        echo -n "$sep"
        echo -n "^bg()^fg() ${windowtitle//^/^^}"

        # Layouting
        # small adjustments
        right="$volume $sep^fg() $acpi $sep^fg() $ip $sep^bg() $date"
        right_text_only=$(echo -n "$right"|sed 's.\^[^(]*([^)]*)..g')
        # get width of right aligned text.. and add some space..
        width=$($textwidth "$font" "$right_text_only")
        offset=14 #14 for the one icon im using that isnt counted
        echo -n "^pa($(($panel_width - $width - $offset)))$right"

        # Finish output
        echo

        # wait for next event
        read line || break
        cmd=( $line )
        # find out event origin
        echo "Command: ${cmd[0]}" >&2
        case "${cmd[0]}" in
            tag*)
                #echo "reseting tags" >&2
                TAGS=( $(herbstclient tag_status $monitor) )
                ;;
            date)
                #echo "reseting date" >&2
                date="${cmd[@]:1}"
                ;;
            heartbeat)
                echo "Got heartbeat!" >&2
                ip=$(net_widget)
                acpi=$(acpi_widget)
                ;;
            volume)
                echo "Got volume update!" >&2
                volume=$(volume_widget)
                ;;
            volume_toggle)
                echo "Got volume update!" >&2
                volume=$(volume_widget toggle)
                ;;
            quit_panel)
                exit
                ;;
            reload)
                exit
                ;;
            focus_changed|window_title_changed)
                windowtitle="${cmd[@]:2}"
                ;;
            *)
                echo "Unknown event!" >&2
        esac
        done
} | dzen2 -w $panel_width -x $x -y $y -fn "$font" -h $panel_height \
    -ta l -bg "$bgcolor" -fg '#efefef'
