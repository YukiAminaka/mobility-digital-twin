import os
import unittest
from unittest.mock import patch

from send_gps import GPSSimulator, Settings, is_success_response


class ResponseTest(unittest.TestCase):
    def test_accepts_2xx_response(self) -> None:
        self.assertTrue(is_success_response("200"))
        self.assertTrue(is_success_response("204 accepted"))

    def test_rejects_error_or_unknown_response(self) -> None:
        self.assertFalse(is_success_response("400 No group ID is specified"))
        self.assertFalse(is_success_response("unexpected"))
        self.assertFalse(is_success_response(""))


class SettingsTest(unittest.TestCase):
    def test_defaults_are_valid(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            settings = Settings.from_environment()

        self.assertEqual(settings.device_id, "bike-001")
        self.assertEqual(settings.destination_host, "funnel.soracom.io")
        self.assertEqual(settings.destination_port, 23080)

    def test_rejects_invalid_port(self) -> None:
        with patch.dict(os.environ, {"DESTINATION_PORT": "70000"}, clear=True):
            with self.assertRaisesRegex(ValueError, "DESTINATION_PORT"):
                Settings.from_environment()


class GPSSimulatorTest(unittest.TestCase):
    def test_generates_expected_payload_and_moves(self) -> None:
        settings = Settings(
            device_id="bike-test",
            destination_host="example.invalid",
            destination_port=23080,
            send_interval_seconds=1.0,
            response_timeout_seconds=1.0,
            initial_latitude=35.0,
            initial_longitude=139.0,
            speed_meters_per_second=10.0,
            initial_heading_degrees=90.0,
            heading_change_degrees_per_second=0.0,
        )
        simulator = GPSSimulator(settings)

        first = simulator.next_sample(timestamp_ms=1_720_000_000_000)
        second = simulator.next_sample(timestamp_ms=1_720_000_001_000)

        self.assertEqual(
            first,
            {
                "device_id": "bike-test",
                "seq": 1,
                "timestamp": 1_720_000_000_000,
                "lat": 35.0,
                "lon": 139.0,
                "speed": 10.0,
                "heading": 90.0,
                "status": "smooth",
            },
        )
        self.assertEqual(second["seq"], 2)
        self.assertAlmostEqual(second["lat"], 35.0, places=5)
        self.assertGreater(second["lon"], 139.0)


if __name__ == "__main__":
    unittest.main()
