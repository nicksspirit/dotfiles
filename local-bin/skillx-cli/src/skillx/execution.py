from __future__ import annotations

import traceback
from argparse import Namespace
from collections.abc import Callable, Generator, Iterable, Iterator, Sequence
from contextlib import contextmanager
from shlex import join as shell_join

from .adapters import CommandResult, InstallRequest, Mutation, Runtime
from .models import (
    Entry,
    EventAction,
    EventKind,
    ExecutionEvent,
    FailureState,
    InstalledSkill,
    ManagedSkill,
    Operation,
    Report,
    Result,
    Status,
)
from .reconcile import (
    ConfigurationError,
    OwnershipError,
    merge_ownership,
    ownership_records,
    parse_inventory,
    parse_ledger,
    parse_lockfile,
    prune_candidates,
    repaired_lockfile,
    serialize_ledger,
    validate,
)

CommandHandler = Callable[[Namespace], Iterable[ExecutionEvent]]


class AgentSkillError(RuntimeError):
    """An operational failure enriched with the command that encountered it."""

    def __init__(
        self,
        operation: Operation,
        lockfile: str,
        message: str,
        diagnostics: str = "",
        failure_state: FailureState = FailureState.NO_CHANGES,
    ) -> None:
        super().__init__(message)
        self.operation = operation
        self.lockfile = lockfile
        self.diagnostics = diagnostics
        self.failure_state = failure_state


def execute(handler: CommandHandler, args: Namespace) -> Iterator[ExecutionEvent]:
    """Run UI-agnostic orchestration and yield facts about its execution."""

    try:
        yield from handler(args)
    except AgentSkillError as error:
        yield from _failure_events(error)
    except (ConfigurationError, OSError) as error:
        contextual = AgentSkillError(
            Operation(args.command), args.lockfile, str(error)
        ).with_traceback(error.__traceback__)
        yield from _failure_events(contextual)


def usage_failure(
    arguments: Sequence[str],
    diagnostics: str,
    default_lockfile: str,
    cause: BaseException | None = None,
) -> tuple[ExecutionEvent, ...]:
    """Represent an argument-parsing failure as the normal event sequence."""
    error = AgentSkillError(
        _operation_from(arguments),
        _option_value(arguments, "--lockfile") or default_lockfile,
        "invalid command usage",
        diagnostics,
    )

    if cause is not None:
        error = error.with_traceback(cause.__traceback__)

    return tuple(_failure_events(error))


def verbosity_from(arguments: Sequence[str]) -> int:
    """Count short and long verbose options before argument parsing succeeds."""

    return sum(
        1 if argument in {"-v", "--verbose"} else len(argument) - 1
        for argument in arguments
        if argument in {"-v", "--verbose"}
        or (argument.startswith("-") and set(argument[1:]) == {"v"})
    )


def _failure_events(error: AgentSkillError) -> Iterator[ExecutionEvent]:
    yield ExecutionEvent(
        EventKind.FAILED,
        error.operation,
        str(error),
        diagnostic=error.diagnostics,
        debug="".join(traceback.format_exception(error)),
        action=EventAction.FAILED,
    )
    yield ExecutionEvent(
        EventKind.COMPLETE,
        error.operation,
        report=Report(
            error.operation,
            Result.FAILED,
            error.lockfile,
            (),
            failure_state=error.failure_state,
        ),
    )


def _complete(report: Report) -> ExecutionEvent:
    return ExecutionEvent(EventKind.COMPLETE, report.operation, report=report)


def _audit(operation: Operation) -> ExecutionEvent:
    return ExecutionEvent(
        EventKind.PHASE,
        operation,
        "Auditing desired skill inventory...",
        action=EventAction.AUDIT,
    )


def _skill_count(count: int) -> str:
    return f"{count} skill{'s' if count != 1 else ''}"


def _confirmation_command(*arguments: str) -> str:
    return shell_join(("skillx", *arguments))


def _blocked(report: Report, *, ownership: bool = False) -> ExecutionEvent:
    if ownership:
        message = (
            "Blocked. Ownership could not be established safely; no files were changed."
        )
    else:
        unresolved = sum(entry.status is not Status.VALID for entry in report.entries)
        noun = "skill" if unresolved == 1 else "skills"
        message = (
            f"Blocked. {unresolved} {noun} could not be resolved; "
            "no files were changed."
        )

    return ExecutionEvent(
        EventKind.BLOCKED,
        report.operation,
        message,
        action=EventAction.BLOCKED,
    )


def validated_lockfile(
    operation: Operation, lockfile: str, runtime: Runtime
) -> tuple[str, Report]:
    """Read desired state and return its reconciliation report."""
    content = runtime.filesystem.read_text(lockfile)
    skills = parse_lockfile(content)
    sources = {
        source: runtime.npx.enumerate_source(source)
        for source in dict.fromkeys(skill.source for skill in skills)
    }

    return content, validate(lockfile, skills, sources, operation)


def inventory_for(
    operation: Operation, lockfile: str, runtime: Runtime
) -> tuple[InstalledSkill, ...]:
    """Load installed skills or raise one contextual external-command failure."""
    result = runtime.npx.inventory()

    if result.returncode != 0:
        raise AgentSkillError(
            operation,
            lockfile,
            "inventory command failed",
            command_diagnostics(result),
        )

    return parse_inventory(result.stdout)


def command_diagnostics(result: CommandResult) -> str:
    """Select the command output that explains a failed external command."""

    return result.stderr.strip() or result.stdout.strip() or "no diagnostic output"


def managed_ledger(ledger: str, runtime: Runtime) -> tuple[ManagedSkill, ...]:
    try:
        content = runtime.filesystem.read_text(ledger)
    except FileNotFoundError:
        return ()

    return parse_ledger(content)


@contextmanager
def transaction(
    mutation: Mutation | None, operation: Operation, lockfile: str, action: str
) -> Generator[None]:
    """Keep rollback available until the mutation and ownership update both succeed."""

    try:
        if mutation is not None and mutation.result.returncode != 0:
            raise AgentSkillError(
                operation,
                lockfile,
                f"{action} failed",
                command_diagnostics(mutation.result),
            )

        yield
    except (AgentSkillError, ConfigurationError, OSError) as error:
        message = (
            str(error)
            if isinstance(error, AgentSkillError)
            else f"{action} could not be committed"
        )
        diagnostics = (
            error.diagnostics if isinstance(error, AgentSkillError) else str(error)
        )
        state = FailureState.NO_CHANGES
        if mutation is not None and mutation.has_rollback:
            try:
                mutation.rollback()
            except OSError as rollback_error:
                diagnostics = f"{diagnostics}; rollback failed: {rollback_error}"
                state = FailureState.RECOVERY_REQUIRED
            else:
                state = FailureState.ROLLED_BACK
        elif mutation is not None and mutation.result.returncode == 0:
            state = FailureState.RECOVERY_REQUIRED
        raise AgentSkillError(
            operation, lockfile, message, diagnostics, state
        ) from error
    else:
        if mutation is not None:
            mutation.commit()


def check(lockfile: str, runtime: Runtime) -> Iterator[ExecutionEvent]:
    """Report source and skill classifications without changing state."""
    yield _audit(Operation.CHECK)
    _, report = validated_lockfile(Operation.CHECK, lockfile, runtime)

    if report.result is Result.BLOCKED:
        yield _blocked(report)

    yield _complete(report)


def sync(
    lockfile: str, ledger: str, dry_run: bool, agent: list[str], runtime: Runtime
) -> Iterator[ExecutionEvent]:
    """Converge installed skills only after every desired entry validates."""
    yield _audit(Operation.SYNC)
    content, report = validated_lockfile(Operation.SYNC, lockfile, runtime)

    if report.result is not Result.OK:
        yield _blocked(report)
        yield _complete(report)

        return

    if not report.entries:
        yield _complete(report)

        return

    managed = managed_ledger(ledger, runtime)
    synced = Report(
        Operation.SYNC,
        Result.PLANNED if dry_run else Result.CHANGED,
        lockfile,
        report.entries,
        planned_changes=len(report.entries),
        dry_run=dry_run,
    )
    action = (
        f"Planning sync for {_skill_count(len(report.entries))}"
        if dry_run
        else f"Syncing {_skill_count(len(report.entries))}"
    )
    yield ExecutionEvent(
        EventKind.PHASE, Operation.SYNC, action, action=EventAction.BATCH
    )

    if dry_run:
        yield _complete(synced)

        return

    skills_by_source: dict[str, list[str]] = {}

    for entry in report.entries:
        skills_by_source.setdefault(entry.source, []).append(entry.skill)

    requests = tuple(
        InstallRequest(source, tuple(skills), tuple(agent))
        for source, skills in skills_by_source.items()
    )

    for current, entry in enumerate(report.entries, start=1):
        yield ExecutionEvent(
            EventKind.PROGRESS,
            Operation.SYNC,
            f"Fetching {entry.source}: {entry.skill}...",
            current=current,
            total=len(report.entries),
            skill_id=entry.skill,
            action=EventAction.FETCH,
        )

    mutation = runtime.npx.install_transaction(requests)

    with transaction(mutation, Operation.SYNC, lockfile, "install"):
        acquired = ownership_records(
            parse_lockfile(content),
            inventory_for(Operation.SYNC, lockfile, runtime),
        )
        runtime.filesystem.write_atomic(
            ledger, serialize_ledger(merge_ownership(managed, acquired))
        )

    yield ExecutionEvent(
        EventKind.MUTATION,
        Operation.SYNC,
        f"Installed or updated {len(report.entries)} requested skill"
        f"{'s' if len(report.entries) != 1 else ''}",
        action=EventAction.BATCH,
    )
    yield ExecutionEvent(
        EventKind.MUTATION,
        Operation.SYNC,
        f"Updated ownership ledger: {ledger}",
        action=EventAction.FILE,
    )
    yield _complete(synced)


def repair(
    lockfile: str, dry_run: bool, yes: bool, runtime: Runtime
) -> Iterator[ExecutionEvent]:
    """Back up and repair only entries proven invalid by enumeration."""
    yield _audit(Operation.REPAIR)
    content, report = validated_lockfile(Operation.REPAIR, lockfile, runtime)
    repairable = {
        entry.skill
        for entry in report.entries
        if entry.status
        in {
            Status.CONFIRMED_MISSING_SOURCE,
            Status.CONFIRMED_MISSING_SKILL,
            Status.CONFIRMED_INVALID_SOURCE,
        }
    }

    if not repairable:
        if report.result is not Result.OK:
            yield _blocked(report)

        yield _complete(report)

        return

    should_change = yes and not dry_run
    yield ExecutionEvent(
        EventKind.PHASE,
        Operation.REPAIR,
        f"{'Repairing' if should_change else 'Planning repair for'} {_skill_count(len(repairable))}",
        action=EventAction.FILE,
    )
    result = Result.PLANNED

    if should_change:
        backup = f"{lockfile}.{runtime.now()}.bak"
        runtime.filesystem.copy(lockfile, backup)
        yield ExecutionEvent(
            EventKind.MUTATION,
            Operation.REPAIR,
            f"Backed up {lockfile} to {backup}",
            action=EventAction.FILE,
        )
        runtime.filesystem.write_atomic(
            lockfile, repaired_lockfile(content, repairable)
        )
        result = Result.CHANGED
        yield ExecutionEvent(
            EventKind.MUTATION,
            Operation.REPAIR,
            f"Updated {lockfile}",
            action=EventAction.FILE,
        )

    yield _complete(
        Report(
            Operation.REPAIR,
            result,
            lockfile,
            report.entries,
            planned_changes=len(repairable),
            dry_run=dry_run,
            confirmation_requested=yes,
            confirmation_command=_confirmation_command(
                "repair", "--lockfile", lockfile, "--yes"
            ),
        )
    )


def adopt(
    lockfile: str, ledger: str, dry_run: bool, yes: bool, runtime: Runtime
) -> Iterator[ExecutionEvent]:
    """Validate and record exact-path ownership for existing installations."""
    yield _audit(Operation.ADOPT)
    content, report = validated_lockfile(Operation.ADOPT, lockfile, runtime)

    if report.result is not Result.OK:
        yield _blocked(report)
        yield _complete(report)

        return

    if not report.entries:
        yield _complete(report)

        return

    try:
        acquired = ownership_records(
            parse_lockfile(content), inventory_for(Operation.ADOPT, lockfile, runtime)
        )
        ledger_content = serialize_ledger(
            merge_ownership(managed_ledger(ledger, runtime), acquired)
        )
    except OwnershipError as error:
        blocked = Report(Operation.ADOPT, Result.BLOCKED, lockfile, error.refusals)
        yield _blocked(blocked, ownership=True)
        yield _complete(blocked)
        return

    adoption_entries = tuple(
        Entry(
            record.skill,
            record.source,
            Status.VALID,
            f"ownership path {record.path} will be recorded in {ledger}",
        )
        for record in acquired
    )

    should_change = yes and not dry_run
    yield ExecutionEvent(
        EventKind.PHASE,
        Operation.ADOPT,
        f"{'Adopting' if should_change else 'Planning adoption for'} {_skill_count(len(report.entries))}",
        action=EventAction.BATCH,
    )
    result = Result.PLANNED

    if should_change:
        runtime.filesystem.write_atomic(ledger, ledger_content)
        result = Result.CHANGED
        yield ExecutionEvent(
            EventKind.MUTATION,
            Operation.ADOPT,
            f"Updated ownership ledger: {ledger}",
            action=EventAction.FILE,
        )

    yield _complete(
        Report(
            Operation.ADOPT,
            result,
            lockfile,
            adoption_entries,
            planned_changes=len(adoption_entries),
            dry_run=dry_run,
            confirmation_requested=yes,
            confirmation_command=_confirmation_command(
                "adopt",
                "--from-lock",
                "--lockfile",
                lockfile,
                "--ledger",
                ledger,
                "--yes",
            ),
        )
    )


def prune(
    lockfile: str, ledger: str, dry_run: bool, yes: bool, runtime: Runtime
) -> Iterator[ExecutionEvent]:
    """Remove only exact-path ledger entries absent from desired state."""
    yield ExecutionEvent(
        EventKind.PHASE,
        Operation.PRUNE,
        "Auditing managed skill inventory...",
        action=EventAction.AUDIT,
    )
    desired = parse_lockfile(runtime.filesystem.read_text(lockfile))
    managed = managed_ledger(ledger, runtime)

    inventory = inventory_for(Operation.PRUNE, lockfile, runtime)

    try:
        candidates = prune_candidates(desired, managed, inventory)
    except OwnershipError as error:
        blocked = Report(Operation.PRUNE, Result.BLOCKED, lockfile, error.refusals)
        yield _blocked(blocked, ownership=True)
        yield _complete(blocked)
        return

    entries = tuple(
        Entry(
            record.skill,
            record.source,
            Status.PRUNABLE,
            f"managed installation at {record.path} is absent from desired state",
        )
        for record in candidates
    )

    if not candidates:
        yield _complete(Report(Operation.PRUNE, Result.OK, lockfile, entries))

        return

    should_change = yes and not dry_run
    yield ExecutionEvent(
        EventKind.PHASE,
        Operation.PRUNE,
        f"{'Pruning' if should_change else 'Planning prune for'} {_skill_count(len(candidates))}",
        action=EventAction.BATCH,
    )

    if not should_change:
        yield _complete(
            Report(
                Operation.PRUNE,
                Result.PLANNED,
                lockfile,
                entries,
                planned_changes=len(candidates),
                dry_run=dry_run,
                confirmation_requested=yes,
                confirmation_command=_confirmation_command(
                    "prune",
                    "--lockfile",
                    lockfile,
                    "--ledger",
                    ledger,
                    "--yes",
                ),
            )
        )

        return

    installed_paths = {item.path for item in inventory}
    removals = tuple(
        record.skill for record in candidates if record.path in installed_paths
    )
    mutation = runtime.npx.remove_transaction(removals) if removals else None

    with transaction(mutation, Operation.PRUNE, lockfile, "removal"):
        removed_paths = {record.path for record in candidates}
        runtime.filesystem.write_atomic(
            ledger,
            serialize_ledger(
                tuple(record for record in managed if record.path not in removed_paths)
            ),
        )

    yield ExecutionEvent(
        EventKind.MUTATION,
        Operation.PRUNE,
        f"Removed {len(removals)} managed skill{'s' if len(removals) != 1 else ''}",
        action=EventAction.BATCH,
    )
    yield ExecutionEvent(
        EventKind.MUTATION,
        Operation.PRUNE,
        f"Updated ownership ledger: {ledger}",
        action=EventAction.FILE,
    )
    yield _complete(
        Report(
            Operation.PRUNE,
            Result.CHANGED,
            lockfile,
            entries,
            planned_changes=len(candidates),
            dry_run=dry_run,
            confirmation_requested=yes,
            confirmation_command=_confirmation_command(
                "prune",
                "--lockfile",
                lockfile,
                "--ledger",
                ledger,
                "--yes",
            ),
        )
    )


def _operation_from(arguments: Sequence[str]) -> Operation:
    try:
        return Operation(arguments[0])
    except (IndexError, ValueError):
        return Operation.UNKNOWN


def _option_value(arguments: Sequence[str], option: str) -> str | None:
    for index, argument in enumerate(arguments):
        if argument == option and index + 1 < len(arguments):
            return arguments[index + 1]

        if argument.startswith(f"{option}="):
            return argument.partition("=")[2]

    return None
