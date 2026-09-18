#!/usr/bin/env python3
"""App Store screenshots for Soul.

Six slides, two styles, two sizes. Each slide is a caption over a framed
capture from the simulator, laid out in HTML with the app's own fonts and
rendered by headless Chrome at Apple's exact pixel sizes. Run it again
whenever the captures in raw/ change:

    python3 store/screenshots/make.py            # today's date
    python3 store/screenshots/make.py 2026-10-01 # a named folder

Output lands in store/screenshots/<date>/<style>/<size>/NN-name.png.
"""
import datetime, os, subprocess, sys, tempfile, pathlib

HERE = pathlib.Path(__file__).resolve().parent
FONTS = HERE.parent.parent / 'app' / 'assets' / 'fonts'
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

SLIDES = [
    ('say-it', '11-reflection-2.png', 'Soul',
     'Say it. Get one line back.',
     'The sentence you did not write yourself.'),
    ('look-closer', '06-reflection.png', 'Look closer',
     'Only if you ask.',
     'What may be pulling against itself, and one question to sit with.'),
    ('how-you-decide', '07-home-tiles-plain.png', 'Home',
     'How you decide, in your own words.',
     'Ten short questions on day one, read back plainly.'),
    ('people', '09-home-map.png', 'Your week',
     'The people in it, as you named them.',
     'Drawn from what you say. It grows as you go.'),
    ('noticing', '03-returning.png', 'Returning',
     'It may be noticing something. You say if it fits.',
     'Yes, no and not sure are equal answers.'),
    ('speak-or-type', '05-capture.png', 'Right now',
     'Speak it or type it. Thirty seconds is plenty.',
     'Audio is deleted the moment the words come back.'),
]

STYLES = {
    'cream': dict(bg='#FFF6EC', ink='#201B15', sub='#6B6055', eyebrow='#C65012', bezel='#201B15', glow='rgba(234,95,23,0.10)'),
    'ink':   dict(bg='#1C1814', ink='#FFF6EC', sub='#C9BBAA', eyebrow='#F0997B', bezel='#0C0A08', glow='rgba(234,95,23,0.22)'),
}

# Apple's sizes: 6.9 inch and 6.5 inch, portrait.
SIZES = {'6.9': (1320, 2868), '6.5': (1284, 2778)}

def html(style, shot, eyebrow, head, sub, w, h):
    c = STYLES[style]
    k = w / 1320  # everything is designed at 1320 wide
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family: Serif; src: url("file://{FONTS}/InstrumentSerif-Regular.ttf"); }}
@font-face {{ font-family: Sans; src: url("file://{FONTS}/Inter.ttf"); font-weight: 100 900; }}
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
html, body {{ width: {w}px; height: {h}px; overflow: hidden; background: {c['bg']}; }}
.page {{ width: 1320px; height: {h / k}px; transform: scale({k}); transform-origin: 0 0;
  position: relative; overflow: hidden; background: {c['bg']}; }}
.glow {{ position: absolute; left: 50%; top: 1500px; width: 1500px; height: 1500px; margin-left: -750px;
  border-radius: 50%; background: {c['glow']}; filter: blur(120px); }}
.copy {{ position: absolute; left: 96px; right: 96px; top: 150px; }}
.eyebrow {{ font: 500 40px/1 Sans; letter-spacing: 7px; text-transform: uppercase; color: {c['eyebrow']}; }}
.head {{ font: 400 124px/1.04 Serif; color: {c['ink']}; margin-top: 40px; letter-spacing: -1.5px; }}
.sub {{ font: 400 46px/1.35 Sans; color: {c['sub']}; margin-top: 36px; max-width: 1000px; }}
.phone {{ position: absolute; left: 50%; top: 860px; width: 1040px; margin-left: -520px;
  border-radius: 150px; background: {c['bezel']}; padding: 26px;
  box-shadow: 0 60px 140px rgba(60,30,10,0.28), 0 0 0 3px rgba(255,255,255,0.06) inset; }}
.phone img {{ display: block; width: 100%; border-radius: 126px; }}
</style></head><body><div class="page">
<div class="glow"></div>
<div class="copy"><div class="eyebrow">{eyebrow}</div><div class="head">{head}</div><div class="sub">{sub}</div></div>
<div class="phone"><img src="file://{HERE}/raw/{shot}"></div>
</div></body></html>'''

def main():
    date = sys.argv[1] if len(sys.argv) > 1 else datetime.date.today().isoformat()
    made = 0
    for style in STYLES:
        for size, (w, h) in SIZES.items():
            out = HERE / date / style / size
            out.mkdir(parents=True, exist_ok=True)
            for i, (name, shot, eyebrow, head, sub) in enumerate(SLIDES, 1):
                with tempfile.NamedTemporaryFile('w', suffix='.html', delete=False) as f:
                    f.write(html(style, shot, eyebrow, head, sub, w, h))
                png = out / f'{i:02d}-{name}.png'
                subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
                                '--force-device-scale-factor=1', f'--window-size={w},{h}',
                                '--allow-file-access-from-files', '--virtual-time-budget=4000',
                                f'--screenshot={png}', f'file://{f.name}'],
                               check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                os.unlink(f.name)
                made += 1
    print(f'{made} screenshots in {HERE / date}')

if __name__ == '__main__':
    main()
