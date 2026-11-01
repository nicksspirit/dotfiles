"""Publish one set of CPU, memory, and battery readings for tmux status formats."""

import fcntl
import subprocess
import sys
import time
from pathlib import Path

import psutil


def readings(battery_icon):
    battery = psutil.sensors_battery()
    if battery is None:
        battery_text = "N/A"
    elif battery.power_plugged:
        battery_text = "⚡"
    else:
        battery_text = f"{battery_icon} {round(battery.percent)}%"
    return {
        "@cpu_mem_cpu": f"{psutil.cpu_percent(interval=1)}%",
        "@cpu_mem_mem": f"{psutil.virtual_memory().percent}%",
        "@cpu_mem_battery": battery_text,
    }


def main(socket):
    server = subprocess.check_output(
        ["tmux", "-S", socket, "display-message", "-p", "#{pid}"], text=True
    ).strip()
    if not server:
        raise RuntimeError("tmux server unavailable")

    with Path(socket).with_name(f"cpu-mem-{server}.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return  # tmux config reload: the existing sampler keeps running

        previous = {}
        # shortcut: an unexpected exit leaves stale values; reload tmux to restart if this occurs.
        while True:
            if subprocess.check_output(
                ["tmux", "-S", socket, "display-message", "-p", "#{pid}"], text=True
            ).strip() != server:
                return
            battery_icon = subprocess.check_output(
                ["tmux", "-S", socket, "show-option", "-gqv", "@cpu_mem_battery_icon"], text=True
            ).strip() or "󰁹"
            for option, value in readings(battery_icon).items():
                if previous.get(option) != value:
                    subprocess.run(["tmux", "-S", socket, "set-option", "-gq", option, value], check=True)
                    previous[option] = value
            time.sleep(4)


if __name__ == "__main__":
    main(sys.argv[1])
