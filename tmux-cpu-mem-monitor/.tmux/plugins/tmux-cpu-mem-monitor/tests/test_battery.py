from unittest.mock import patch

import pytest

from src.battery import (
    CHARGING_ICON,
    get_battery_compact,
    get_battery_long,
    get_battery_percent,
    get_battery_time,
)


@patch("src.battery._get_charging_status", return_value=True)
@patch("psutil.sensors_battery")
def test_charging(mock_battery, mock_charging_status):
    """Test the battery charging status"""
    assert get_battery_percent() == CHARGING_ICON
    assert get_battery_percent("󰁹") == CHARGING_ICON
    assert get_battery_time() == CHARGING_ICON
    assert get_battery_long() == "Charging"
    assert get_battery_compact() == CHARGING_ICON


@patch("src.battery._get_charging_status", return_value=False)
@patch("psutil.sensors_battery")
@pytest.mark.parametrize(
    "percentage,status",
    [
        (100, "Fully charged"),
        (95, "Almost full"),
        (74, "More than 3/4 full"),
        (50, "More than half full"),
        (26, "Less than half full"),
        (6, "Battery is running low"),
        (2, "Battery is almost empty"),
        (1, "I'm dying over here"),
        (0, "Out of battery"),
    ],
)
def test_battery_long(mock_battery, mock_charging_status, percentage, status):
    """Test battery with a range of percentages"""
    mock_battery.return_value.percent = percentage
    result = get_battery_long()
    assert result == status


@patch("src.battery._get_charging_status", return_value=False)
@patch("psutil.sensors_battery")
def test_battery_percent(mock_battery, mock_charging_status):
    mock_battery.return_value.percent = 62.7
    assert get_battery_percent() == "63%"
    assert get_battery_percent("󰁹") == "󰁹 63%"


@patch("src.battery._get_charging_status", return_value=False)
@patch("psutil.sensors_battery")
def test_battery_compact(mock_battery, mock_charging_status):
    """Test compact battery level blocks across the full range."""
    for percentage in range(0, 101, 10):
        mock_battery.return_value.percent = percentage
        character = get_battery_compact()
        assert 0x00002581 <= ord(character) <= 0x00002588


@patch("psutil.sensors_battery", return_value=None)
def test_battery_unavailable(mock_battery):
    assert get_battery_percent() == "N/A"
    assert get_battery_time() == "N/A"
    assert get_battery_long() == "N/A"
    assert get_battery_compact() == "N/A"
