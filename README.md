# Rubyfin

Just a little CLI thing I'm messing around with for my Jellyfin server. Nothing serious, mostly just testing out some Ruby stuff and seeing if I can make a TUI that doesn't feel absolutely terrible (even thought it still does).

## What It Does (When It Works)

- Logs into your Jellyfin server
- Browses your libraries
- Picks stuff and plays it in mpv

That's it really. Work in progress, very janky, mostly for fun.

## Requirements

- Ruby (obviously)
- mpv for actually watching stuff
- A Jellyfin server running somewhere

## Setup

First time you run it it'll ask for your server URL, username, password. Stores that in `~/.config/rubyfin/config.json`. Nothing fancy. Just delete that file if you need to reset credentials or server info.
# rubyfin
