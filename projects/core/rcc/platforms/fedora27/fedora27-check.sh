#!/bin/sh --noprofile
if test -f /etc/fedora-release; then
  read v0 v1 <<EOF
`sed < /etc/fedora-release 's/^\(.\).*release \([0-9]\+\).*/\1 \2/' | tr A-Z a-z`
EOF
  if test "$v0" = "f" -a "$v1" == "27"; then
    echo $1 f27 $2
    exit 0
  fi
fi
exit 1
