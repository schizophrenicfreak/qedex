#!/usr/bin/env python3
import glob, json, os, socket, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
INTERVAL = 2.0


def run(*cmd, timeout=4):
    try:
        return subprocess.run(list(cmd), capture_output=True, text=True, timeout=timeout).stdout.strip()
    except Exception:
        return ""


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read()
    except Exception:
        return default


def cpu():
    v = list(map(int, read("/proc/stat").splitlines()[0].split()[1:]))
    return v[3] + v[4], sum(v)


def mem():
    m = {}
    for line in read("/proc/meminfo").splitlines():
        k, v = line.split(":")
        m[k] = int(v.split()[0]) * 1024
    return m["MemTotal"] - m["MemAvailable"], m["MemTotal"]


def battery():
    for d in sorted(glob.glob("/sys/class/power_supply/BAT*")):
        try:
            return int(read(d + "/capacity")), read(d + "/status").strip().upper()
        except Exception:
            pass
    return -1, "NONE"


def uptime():
    s = int(float(read("/proc/uptime", "0").split()[0]))
    d, s = divmod(s, 86400)
    h, s = divmod(s, 3600)
    m = s // 60
    return (f"{d}d " if d else "") + (f"{h}h " if h else "") + f"{m}m"


def default_iface():
    for line in read("/proc/net/route").splitlines()[1:]:
        f = line.split()
        if len(f) > 3 and f[1] == "00000000" and int(f[3], 16) & 2:
            return f[0]
    return None


def net_bytes(iface):
    for line in read("/proc/net/dev").splitlines():
        name, _, rest = line.partition(":")
        if name.strip() == iface:
            f = rest.split()
            return int(f[0]), int(f[8])
    return None


def top_procs():
    out = run("ps", "-eo", "comm:16,%cpu,%mem", "--sort=-%cpu", "--no-headers")
    return "\n".join(out.splitlines()[:6])


def main():
    host = socket.gethostname().split(".")[0]
    sens = {}
    pi, pt = cpu()
    prev_net = None
    n = 0
    nxt = time.monotonic() + INTERVAL
    while True:
        time.sleep(max(0.0, nxt - time.monotonic()))
        nxt += INTERVAL
        try:
            i, t = cpu()
            di, dt = i - pi, t - pt
            pi, pt = i, t
            cp = 100.0 * (1 - di / dt) if dt else 0.0

            if n % 2 == 0:
                try:
                    sens = json.loads(run("bash", os.path.join(HERE, "sens.sh")))
                except Exception:
                    pass
            n += 1

            down = up = 0
            iface = default_iface()
            cur = net_bytes(iface) if iface else None
            now = time.monotonic()
            if cur and prev_net and prev_net[0] == iface and now > prev_net[3]:
                el = now - prev_net[3]
                down = max(0, (cur[0] - prev_net[1]) / el / 1024)
                up = max(0, (cur[1] - prev_net[2]) / el / 1024)
            prev_net = (iface, cur[0], cur[1], now) if cur else None

            u, tot = mem()
            b, bs = battery()
            out = {"cpu": round(cp, 1), "memu": u, "memt": tot, "uptime": uptime(), "host": host,
                   "procs": top_procs(), "down": round(down), "up": round(up),
                   "bat": b, "bat_s": bs}
            out.update(sens)
            print(json.dumps(out), flush=True)
        except BrokenPipeError:
            sys.exit(0)
        except Exception as e:
            print(f"stats.py: {e}", file=sys.stderr, flush=True)


if __name__ == "__main__":
    main()
