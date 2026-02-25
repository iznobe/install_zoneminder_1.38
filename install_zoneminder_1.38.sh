#!/bin/bash
echo "This script installs LAMP + ZoneMinder 1.38.x on Debian 13 , Ubuntu 24.04 ( and probably newer versions but not tested ) and Linux Mint "

if ((UID)); then
  echo "This script must be run as root! Use « sudo ./$0 » or « sudo bash $0 »."
  exit 0
fi

