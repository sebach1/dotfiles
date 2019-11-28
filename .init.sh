#!bin/sh
sleep 3
i3-msg 'workspace 1; exec /usr/bin/google-chrome --force-device-scale-factor=0.85'
i3-msg 'workspace 2; exec /usr/bin/urxvt'
i3-msg 'workspace 3; exec /usr/bin/code'
i3-msg 'workspace 4; exec /usr/bin/slack'
i3-msg 'workspace 10; exec /usr/bin/spotify'

