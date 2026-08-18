# spotify

Search Spotify from the launcher and start playback on whatever device you have
open.

```
sp:kind of blue              tracks, then albums, then artists
sp:kind of blue type:album   albums only
sp:miles davis type:artist   artists only
```

A track row carries the artists, the album and the year, the duration, and the
cover art. Enter plays it. The action panel adds Add to Queue, Open in Spotify
and Copy Link.

## You need your own Spotify app

There is no way around this. The token the Spotify desktop app holds is not
reachable by anything else, and the Web API will not talk to you without a
client id of your own. Making one takes about a minute and costs nothing.

1. Go to [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard)
   and log in with the account you listen on.
2. **Create app**. Name and description can be anything.
3. Redirect URI: `http://127.0.0.1:8888/callback`. Type it exactly. Spotify
   stopped accepting `localhost` as a redirect host in 2025, so it has to be the
   literal loopback address, and the port has to be 8888.
4. Tick **Web API**, save, then copy the **Client ID** from the app's settings.
   There is a client secret beside it. You do not need it and should not paste
   it anywhere: this unit uses PKCE precisely so that nothing has to hold one.
5. Your own account can already use an app you own. If you want someone else on
   this machine to use it, add them under **User Management**.

## Setup

```bash
bo add spotify
omacast-spotify-auth
```

It asks for the client id, opens your browser at Spotify's approval page, and
catches the redirect on 127.0.0.1:8888 with a one request http server that exits
as soon as the tab comes back. Approve, close the tab, done.

The scopes it asks for are the ones the rows need and nothing else:

```
user-read-playback-state  user-modify-playback-state  user-read-private
playlist-read-private     user-library-read
```

Until that has run, the extension does not load at all. Its `when` condition
looks for the credentials file, so an unconfigured install costs the launcher
nothing and shows nothing.

## Where the credentials live

`~/.local/state/omarchy/omacast-spotify.json`, mode 600.

Not in `~/.config/omarchy/omacast.json`, and not in this repo. That config
file is meant to be committed and carried between machines; this one is a live
Spotify session for anyone who can read it. The access token is refreshed in
place when it expires, so the file rewrites itself roughly every hour.

To disconnect, delete the file. The extension goes quiet again and Spotify
forgets the grant once you remove the app under
[Apps in your account settings](https://www.spotify.com/account/apps/).

## Playback needs Premium

Search works on any account. `PUT /v1/me/player/play` is a Premium only
endpoint, so a free account gets a notification saying so instead of music.
`omacast-spotify-auth` checks this at the end of setup and warns you there.

Playback also needs somewhere to play. Spotify has no concept of "start on this
laptop" without a device already registered, so open the Spotify app once after
a reboot. If there is a known device sitting idle, the row wakes it. If there is
no device at all, the row says `no Spotify device to play on` in its subtitle
before you press anything.

## Bits worth knowing

`bo doctor` checks for `curl` and `jq`. Setup also needs `python3`, which is on
every Omarchy install, for the PKCE hashing and the redirect listener.

No access token is ever passed as a command line argument. Both scripts hand
curl its options on stdin with `-K -`, because anything in argv is readable
through `ps` by any account on the machine for as long as the request runs, and
a header file on disk would only move the same secret somewhere it persists.
