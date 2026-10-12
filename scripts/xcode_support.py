"""Bounded process execution shared by local Xcode commands."""

import os
import signal
import subprocess
from contextlib import contextmanager
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class RunError(Exception):
    pass


class InterruptedRun(RunError):
    pass


class CommandTimeout(RunError):
    pass


@contextmanager
def blocked_termination_signals():
    """Defer a second interrupt until owned process/device cleanup finishes."""
    if hasattr(signal, "pthread_sigmask"):
        previous = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGINT, signal.SIGTERM})
        try:
            yield
        finally:
            signal.pthread_sigmask(signal.SIG_SETMASK, previous)
    else:
        yield


class InterruptState:
    def __init__(self):
        self.interrupted = False
        self.cleaning = False

    def handle(self, _signum, _frame):
        first = not self.interrupted
        self.interrupted = True
        if first and not self.cleaning:
            raise InterruptedRun("Interrupted by signal")


class Executor:
    """Bounded subprocess execution; a timeout or interrupt stops only its process group."""

    def run(self, command, timeout, log=None):
        output = open(log, "w", encoding="utf-8") if log else subprocess.PIPE
        process = None
        try:
            process = subprocess.Popen(
                command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
                text=True, start_new_session=True,
            )
            try:
                stdout, _ = process.communicate(timeout=timeout)
            except (subprocess.TimeoutExpired, KeyboardInterrupt, InterruptedRun):
                self._stop(process)
                raise
            return process.returncode, stdout or ""
        except subprocess.TimeoutExpired as exc:
            label = " ".join(command[:3]) if command[:2] == ["xcrun", "simctl"] else command[0]
            raise CommandTimeout(f"Timed out after {timeout}s: {label}") from exc
        finally:
            if log:
                output.close()
            elif process and process.stdout:
                process.stdout.close()

    @staticmethod
    def _stop(process):
        with blocked_termination_signals():
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                pass
            # The direct child may have exited while descendants still hold its
            # stdout pipe. Always finish the owned group after a failed command.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)


def require_command(executor, command, timeout, log=None):
    code, output = executor.run(command, timeout, log)
    if code:
        raise RunError(f"{command[0]} exited {code}: {output.strip()[:500]}")
    return output


