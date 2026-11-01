#!/usr/bin/env python3
import atexit, json, re, shutil, signal, subprocess, sys

ROWS = [
    ["ESC","1","2","3","4","5","6","7","8","9","0","-","=","BACK"],
    ["TAB","Q","W","E","R","T","Y","U","I","O","P","[","]","ENTER"],
    ["CAPS","A","S","D","F","G","H","J","K","L",";"],
    ["SHIFT","Z","X","C","V","B","N","M",",",".","/","SHIFT"],
    ["CTRL","FN","SPACE","ALT GR","CTRL"],
]

MAP = {
    "KEY_ESC": "ESC", "KEY_MINUS": "-", "KEY_EQUAL": "=", "KEY_BACKSPACE": "BACK",
    "KEY_TAB": "TAB", "KEY_LEFTBRACE": "[", "KEY_RIGHTBRACE": "]",
    "KEY_ENTER": "ENTER", "KEY_KPENTER": "ENTER", "KEY_CAPSLOCK": "CAPS",
    "KEY_SEMICOLON": ";", "KEY_LEFTSHIFT": "SHIFT", "KEY_RIGHTSHIFT": "SHIFT",
    "KEY_COMMA": ",", "KEY_DOT": ".", "KEY_SLASH": "/",
    "KEY_LEFTCTRL": "CTRL", "KEY_RIGHTCTRL": "CTRL", "KEY_SPACE": "SPACE",
    "KEY_RIGHTALT": "ALT GR",
}
for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
    MAP["KEY_" + c] = c
for d in "1234567890":
    MAP["KEY_" + d] = d

labels = {k for r in ROWS for k in r}
held = set()
last = None


def emit(force=False):
    global last
    on = {m for k in held if (m := MAP.get(k))}
    state = {k: int(k in on) for k in labels}
    if force or state != last:
        last = state
        print(json.dumps(state, separators=(",", ":")), flush=True)


def main():
    if not shutil.which("libinput"):
        sys.exit("keys.py: 'libinput' not found (install libinput-tools / libinput-utils)")
    cmd = ["libinput", "debug-events", "--show-keycodes"]
    if shutil.which("stdbuf"):
        cmd = ["stdbuf", "-oL"] + cmd
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True, bufsize=1)

    def stop(*_):
        if p.poll() is None:
            p.terminate()
    atexit.register(stop)
    signal.signal(signal.SIGTERM, lambda *a: (stop(), sys.exit(0)))

    emit(force=True)
    pat = re.compile(r"KEYBOARD_KEY.*?(KEY_\w+) \(\d+\) (pressed|released)")
    try:
        for line in p.stdout:
            m = pat.search(line)
            if not m:
                continue
            (held.add if m.group(2) == "pressed" else held.discard)(m.group(1))
            emit()
    except BrokenPipeError:
        sys.exit(0)
    sys.exit("keys.py: libinput exited. Are you in the 'input' group? (log out and back in after adding yourself)")


if __name__ == "__main__":
    main()
