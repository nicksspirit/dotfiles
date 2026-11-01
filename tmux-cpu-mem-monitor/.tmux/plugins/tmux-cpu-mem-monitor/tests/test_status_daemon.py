import fcntl
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import status_daemon


class StatusDaemonTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which("tmux"), "tmux required")
    def test_writes_only_to_its_socket(self):
        with tempfile.TemporaryDirectory() as directory:
            sockets = [f"{directory}/{name}" for name in ("a", "b")]
            for socket in sockets:
                subprocess.run(["tmux", "-S", socket, "-f", "/dev/null", "new-session", "-d", "-s", "test"], check=True)
            daemon = None
            try:
                env = dict(os.environ, TMUX=f"{sockets[1]},0,0")
                daemon = subprocess.Popen([sys.executable, status_daemon.__file__, sockets[0]], env=env)
                for _ in range(40):
                    output = subprocess.check_output(["tmux", "-S", sockets[0], "show-option", "-gqv", "@cpu_mem_cpu"], text=True)
                    if output.strip():
                        break
                    time.sleep(0.1)
                self.assertTrue(output.strip(), "sampler did not publish readings")
                self.assertFalse(subprocess.check_output(["tmux", "-S", sockets[1], "show-option", "-gqv", "@cpu_mem_cpu"], text=True).strip())
            finally:
                if daemon is not None:
                    daemon.terminate()
                    daemon.wait(timeout=5)
                for socket in sockets:
                    subprocess.run(["tmux", "-S", socket, "kill-session", "-t", "test"], check=False, stderr=subprocess.DEVNULL)

    def test_readings_keep_existing_status_format(self):
        with patch.object(status_daemon.psutil, "cpu_percent", return_value=18.5), patch.object(
            status_daemon.psutil, "virtual_memory"
        ) as memory, patch.object(status_daemon.psutil, "sensors_battery") as battery:
            memory.return_value.percent = 42.0
            battery.return_value.power_plugged = False
            battery.return_value.percent = 74.6
            self.assertEqual(
                status_daemon.readings("󰁹"),
                {"@cpu_mem_cpu": "18.5%", "@cpu_mem_mem": "42.0%", "@cpu_mem_battery": "󰁹 75%"},
            )
            self.assertEqual(status_daemon.readings("BAT")["@cpu_mem_battery"], "BAT 75%")
            battery.return_value.power_plugged = True
            self.assertEqual(status_daemon.readings("󰁹")["@cpu_mem_battery"], "⚡")
            battery.return_value = None
            self.assertEqual(status_daemon.readings("󰁹")["@cpu_mem_battery"], "N/A")

    def test_reload_does_not_start_a_second_sampler(self):
        with tempfile.TemporaryDirectory() as directory:
            with (Path(directory) / "cpu-mem-123.lock").open("a") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                with patch.object(
                    status_daemon.subprocess, "check_output", side_effect=["123"]
                ), patch.object(status_daemon, "readings") as readings:
                    status_daemon.main(f"{directory}/socket")
                    readings.assert_not_called()

    def test_exits_if_tmux_server_changes(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(
            status_daemon.subprocess, "check_output", side_effect=["123", "456"]
        ), patch.object(status_daemon, "readings") as readings:
            status_daemon.main(f"{directory}/socket")
            readings.assert_not_called()

    def test_publishes_changed_values_only(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(
            status_daemon.subprocess, "check_output", side_effect=["123", "123", "󰁹", "123", "󰁹"]
        ), patch.object(status_daemon, "readings", side_effect=[
            {"@cpu_mem_cpu": "10%", "@cpu_mem_mem": "20%", "@cpu_mem_battery": "⚡"},
            {"@cpu_mem_cpu": "10%", "@cpu_mem_mem": "20%", "@cpu_mem_battery": "⚡"},
        ]), patch.object(status_daemon.subprocess, "run") as run, patch.object(
            status_daemon.time, "sleep", side_effect=[None, StopIteration]
        ):
            with self.assertRaises(StopIteration):
                status_daemon.main(f"{directory}/socket")
            self.assertEqual(run.call_count, 3)
            self.assertEqual(run.call_args_list[0].args[0], ["tmux", "-S", f"{directory}/socket", "set-option", "-gq", "@cpu_mem_cpu", "10%"])


if __name__ == "__main__":
    unittest.main()
