#!/bin/bash

# Caveats: this scripts doesn't handle pagination
# See https://api.atnd.org/ for how to use ATND API

set -eu

if [ $# -ne 1 ]; then
  echo "usage: $0 <owner_id>" 1>&2
  exit 1
fi

readonly owner_id="$1"
readonly wait_seconds=1

echo "Archiving the events of ID (${owner_id}) to the directory ($(dirname "$0"))"

echo 'Preparing directories'
mkdir -p attendance events images

echo -n 'Downloading events'
for format in atom ics json xml; do
  wget -q -O "events/events.${format}" "https://api.atnd.org/events/?format=${format}&count=100&owner_id=${owner_id}"
  echo -n .
  sleep "$wait_seconds"
done
echo

echo -n 'Downloading attendance'
for event_id in $(jq '.events[].event.event_id' events/events.json); do
  for format in json xml; do
    wget -q -O "attendance/${event_id}.${format}" "https://api.atnd.org/events/users/?event_id=${event_id}&format=${format}"
    echo -n .
    sleep "$wait_seconds"
  done
done
echo

echo -n 'Downloading images'
for event_id in $(jq '.events[].event.event_id' events/events.json); do
  image_url=$(wget -q -O - "https://atnd.org/events/${event_id}" | grep og:image | awk -F '"' '{ print $4 }' | grep event_images || true)
  if [ -z "$image_url" ]; then
    continue
  fi
  extension=$(echo "$image_url" | awk -F '.' '{ print $NF }' | awk -F '?' '{ print $1 }')
  wget -q -O "images/${event_id}.${extension}" "$image_url"
  echo -n .
  sleep "$wait_seconds"
done
echo

echo 'Completed!'
