#!bin/sh
sleep 3
i3-msg 'workspace 1:Chr; exec /usr/bin/google-chrome-stable --force-device-scale-factor=0.85'
i3-msg 'workspace 2:Sh; exec /usr/bin/urxvt'
i3-msg 'workspace 3:Vs; exec /usr/bin/code'
i3-msg 'workspace 4:Sck; exec /usr/bin/slack'
i3-msg 'workspace 10:Music; exec /usr/bin/spotify'

