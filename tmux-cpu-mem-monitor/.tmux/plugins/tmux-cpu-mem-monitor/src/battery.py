import argparse
from datetime import timedelta

import psutil

CHARGING_ICON = "⚡"


def _get_battery():
    return psutil.sensors_battery()


def _get_charging_status(battery=None):
    """Get the battery charging status"""
    if battery is None:
        battery = _get_battery()
    return battery is not None and battery.power_plugged


def get_battery_percent(icon=""):
    """Display battery percentage"""
    if (battery := _get_battery()) is None:
        return "N/A"

    if _get_charging_status(battery):
        return CHARGING_ICON

    percentage = f"{round(battery.percent)}%"
    return f"{icon} {percentage}" if icon else percentage


def get_battery_time():
    """Display battery time remaining in hours and minutes"""
    if (battery := _get_battery()) is None:
        return "N/A"

    if _get_charging_status(battery):
        return CHARGING_ICON

    time_left = timedelta(seconds=battery.secsleft)

    return str(time_left).split(".")[0]


def get_battery_long():
    """Display the remaining battery amount in a human-readable format.

    Examples:
    - Charging
    - Out of battery
    - Battery is almost empty
    - Battery is running low
    - More than half full
    ...
    """
    if (battery := _get_battery()) is None:
        return "N/A"

    if _get_charging_status(battery):
        return "Charging"

    battery_status = {
        (100, 100): "Fully charged",
        (95, 99): "Almost full",
        (74, 94): "More than 3/4 full",
        (50, 74): "More than half full",
        (26, 49): "Less than half full",
        (6, 25): "Battery is running low",
        (2, 5): "Battery is almost empty",
        (1, 1): "I'm dying over here",
        (0, 0): "Out of battery",
    }

    for (low, high), status in battery_status.items():
        if low <= battery.percent <= high:
            return status


def get_battery_compact():
    """Display battery level with a compact block character"""
    if (battery := _get_battery()) is None:
        return "N/A"

    if _get_charging_status(battery):
        return CHARGING_ICON

    level = _remap_range(battery.percent, 0, 100, 0, 7)
    return chr(0x00002581 + int(level))


def _remap_range(value, low, high, remap_low, remap_high):
    """Remap battery percentage to a whole number from 0 to 7"""
    return remap_low + (value - low) * (remap_high - remap_low) // (high - low)


def main(args):
    if args.percent:
        battery = get_battery_percent(args.icon)
    elif args.time:
        battery = get_battery_time()
    elif args.long:
        battery = get_battery_long()
    elif args.compact:
        battery = get_battery_compact()
    else:
        battery = get_battery_percent()

    print(battery)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    type_option = parser.add_mutually_exclusive_group()
    type_option.add_argument(
        "-p",
        "--percent",
        action="store_true",
        default=False,
        help="display remaining battery percentage",
    )
    parser.add_argument("--icon", default="", help="prefix the percentage with an icon")
    type_option.add_argument(
        "-t",
        "--time",
        action="store_true",
        default=False,
        help="display remaining battery time",
    )

    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "-l",
        "--long",
        action="store_true",
        default=False,
        help="display remaining battery as a sentence",
    )
    parser.add_argument(
        "-c",
        "--compact",
        action="store_true",
        default=False,
        help="display remaining battery as a compact block character",
    )
    args = parser.parse_args()
    main(args)
