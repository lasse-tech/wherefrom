# Media

`Icon.png` is the addon list icon referenced by `## IconTexture` in the TOC.

WoW reads PNG and BLP here. The addon list draws it at 64×64 logical pixels, so a
64×64 or 128×128 PNG with transparency is the right thing to put here; anything
larger is only downscaled, and a file without an alpha channel shows its
background against the list.

`Icon.svg` is what `Icon.png` is rendered from:

```sh
rsvg-convert -w 128 -h 128 -o Media/Icon.png Media/Icon.svg
```

It is tracked so the icon can be changed, and left out of releases.
