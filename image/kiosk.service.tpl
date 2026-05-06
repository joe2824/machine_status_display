[Unit]
Description=Machine Status Display
After=multi-user.target
After=systemd-user-sessions.service
Conflicts=getty@tty1.service

[Service]
User=$KIOSK_USER
Environment="XDG_RUNTIME_DIR=$KIOSK_RUNDIR"
Environment="HOME=/home/$KIOSK_USER"
Environment="XDG_DATA_HOME=/home/$KIOSK_USER/.local/share"
Environment="XDG_CONFIG_HOME=/home/$KIOSK_USER/.config"
Environment="GDK_BACKEND=wayland"
Environment="XDG_SESSION_TYPE=wayland"
Environment="WEBKIT_DISABLE_DMABUF_RENDERER=1"
Environment="WLR_NO_HARDWARE_CURSORS=1"
Environment="NO_AT_BRIDGE=1"
StandardOutput=journal
StandardError=journal
Restart=always
ExecStartPre=/bin/sh -c 'udevadm settle --timeout=10 || true'
ExecStart=/usr/bin/cage -- dbus-run-session /usr/bin/machine_status_display
ExecStartPost=+/bin/sh -c '/usr/bin/chvt 1 || true'
ExecStartPost=+/bin/sh -c '(sleep 5; /usr/bin/udevadm trigger --subsystem-match=input --action=add) & (sleep 12; /usr/bin/udevadm trigger --subsystem-match=input --action=add) & true'

[Install]
WantedBy=multi-user.target
