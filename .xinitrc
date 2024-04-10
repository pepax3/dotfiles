flameshot &
feh --bg-scale ~/berserk-rice/background.png &
xrandr --output eDP-1 --brightness 0.6 &
dunst &
slstatus &
export _JAVA_AWT_WM_NONREPARENTING=1
while true; do
    dwm >/dev/null 2>&1
done
