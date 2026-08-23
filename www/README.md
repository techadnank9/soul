# www

The public site at soulspacehealth.com. One page, no framework, no build step.
Open `index.html` in a browser and what you see is what ships.

```
index.html      the whole page. Styles and script are inline, on purpose
screens/        real screenshots, captured from the running app
brand/          the wordmark favicon and Apple's App Store badge
vercel.json     headers and caching
```

## The screenshots are real

Every image in `screens/` came off a booted simulator running this repo's
Flutter client against a local API, with the demo student from
`npm run seed:demo`. The sentences under the themes in `returning-theme.png`
were written by the pattern verdict job, not by hand. If a screen changes,
retake the shot rather than editing the picture, and keep the file name
matching the tab it came from.

| File | The screen it is |
| --- | --- |
| `screens/first-run.png` | The intro, before anything is asked |
| `screens/capture.png` | Capture, spoken or typed |
| `screens/this-week.png` | The week ring and the day dots |
| `screens/returning.png` | Worth keeping and worth stopping |
| `screens/returning-theme.png` | One theme, and the entries under it |

## The App Store badge

`brand/app-store-badge.svg` is Apple's own artwork, downloaded unmodified from
developer.apple.com. Apple's marketing guidelines forbid recolouring it and ask
for a minimum height with clear space around it, which the `.badge` rule holds.
Only the black lockup is served from that URL, so on the dark theme it sits on a
light plate. To use Apple's white lockup instead, take it from Marketing
Resources and drop `--badge-plate`.

## Running it

```
python3 -m http.server 8282 --directory www
```

## Deploying

Vercel, with the root directory set to `www`. There is nothing to build, so the
framework preset is Other and the build command stays empty.

## The voice rules apply here too

Everything on this page follows CONTEXT.md: no hyphens or dashes anywhere a
person reads, no exclamation marks, no emoji, no emotion labels, situations
rather than traits. The two columns under `It says` and `It never says` are
quoted from `prompts/beat_one.v1.md` and CONTEXT.md and should stay quoted.
