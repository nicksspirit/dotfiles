from __future__ import annotations

import io
import os
import sys
from collections.abc import Sequence
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

from .adapters import Runtime, default_runtime
from .cli import ArgumentParser
from .execution import (
    adopt,
    check,
    execute,
    prune,
    repair,
    sync,
    usage_failure,
    verbosity_from,
)
from .ui import Renderer

DEFAULT_LOCKFILE = os.environ.get(
    "LOCKFILE", str(Path.home() / ".agents" / ".skill-lock.json")
)
DEFAULT_LEDGER = str(Path.home() / ".agents" / ".skillx-managed.json")

cli = ArgumentParser(prog="skillx")
cli.enable_subcommands()


def _common_args(
    *, ledger: bool = False, dry_run: bool = False, yes: bool = False
) -> tuple[object, ...]:
    arguments: list[object] = [
        cli.argument("--lockfile", default=DEFAULT_LOCKFILE),
        cli.argument("--json", action="store_true", dest="json_output"),
        cli.argument("-v", "--verbose", action="count", default=0),
    ]

    if ledger:
        arguments.insert(1, cli.argument("--ledger", default=DEFAULT_LEDGER))

    if dry_run:
        arguments.append(cli.argument("--dry-run", action="store_true"))

    if yes:
        arguments.append(cli.argument("--yes", action="store_true"))

    return tuple(arguments)


check = cli.command(
    *_common_args(),
    help="validate desired and remote state without mutation",
)(check)


sync = cli.command(
    *_common_args(ledger=True, dry_run=True),
    cli.argument("--agent", action="extend", nargs="+", default=[]),
    help="validate and install or update desired skills",
)(sync)


repair = cli.command(
    *_common_args(dry_run=True, yes=True),
    help="remove confirmed-invalid desired entries",
)(repair)


adopt = cli.command(
    cli.argument("--from-lock", action="store_true", required=True),
    *_common_args(ledger=True, dry_run=True, yes=True),
    help="explicitly transfer custody of installed desired skills",
)(adopt)


prune = cli.command(
    *_common_args(ledger=True, dry_run=True, yes=True),
    help="remove unambiguously owned skills absent from desired state",
)(prune)


def main(argv: Sequence[str] | None = None, *, runtime: Runtime | None = None) -> int:
    """Parse arguments, consume execution events, and select the output mode."""
    runtime = default_runtime() if runtime is None else runtime
    arguments = list(sys.argv[1:] if argv is None else argv)
    parser_diagnostics = io.StringIO()

    try:
        with redirect_stdout(runtime.stdout), redirect_stderr(parser_diagnostics):
            args = cli.parse_args(arguments)
    except SystemExit as error:
        exit_code = 0 if error.code is None else int(error.code)
        if exit_code == 0:
            return 0
        events = usage_failure(
            arguments,
            parser_diagnostics.getvalue(),
            DEFAULT_LOCKFILE,
            error,
        )
        return Renderer(
            runtime.stdout,
            runtime.stderr,
            verbosity=verbosity_from(arguments),
        ).render(
            events,
            json_output="--json" in arguments,
        )

    if args.command is None:
        cli.print_help(file=runtime.stdout)

        return 0

    args.runtime = runtime
    events = execute(args.func, args)

    return Renderer(runtime.stdout, runtime.stderr, verbosity=args.verbose).render(
        events,
        json_output=args.json_output,
    )


if __name__ == "__main__":
    raise SystemExit(main())
