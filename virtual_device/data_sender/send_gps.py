#!/usr/bin/env python3
"""Generate virtual GPS samples and send them to SORACOM Funnel over UDP."""

from __future__ import annotations

import json
import logging
import math
import os
import signal
import socket
import threading
import time
from dataclasses import dataclass
from typing import Any


EARTH_RADIUS_METERS = 6_371_000.0
MAX_RESPONSE_BYTES = 4_096


def _read_float(name: str, default: float, *, minimum: float | None = None) -> float:
    raw_value = os.getenv(name, str(default))
    try:
        value = float(raw_value)
    except ValueError as error:
        raise ValueError(f"{name} must be a number, got {raw_value!r}") from error
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    if minimum is not None and value < minimum:
        raise ValueError(f"{name} must be at least {minimum}")
    return value


def _read_int(name: str, default: int, *, minimum: int, maximum: int) -> int:
    raw_value = os.getenv(name, str(default))
    try:
        value = int(raw_value)
    except ValueError as error:
        raise ValueError(f"{name} must be an integer, got {raw_value!r}") from error
    if not minimum <= value <= maximum:
        raise ValueError(f"{name} must be between {minimum} and {maximum}")
    return value


def is_success_response(response: str) -> bool:
    """Return whether a SORACOM UDP response starts with a 2xx status."""
    status_text = response.split(maxsplit=1)[0] if response else ""
    try:
        status_code = int(status_text)
    except ValueError:
        return False
    return 200 <= status_code < 300


@dataclass(frozen=True)
class Settings:
    device_id: str
    destination_host: str
    destination_port: int
    send_interval_seconds: float
    response_timeout_seconds: float
    initial_latitude: float
    initial_longitude: float
    speed_meters_per_second: float
    initial_heading_degrees: float
    heading_change_degrees_per_second: float

    @classmethod
    def from_environment(cls) -> "Settings":
        device_id = os.getenv("DEVICE_ID", "bike-001").strip()
        destination_host = os.getenv("DESTINATION_HOST", "funnel.soracom.io").strip()
        if not device_id:
            raise ValueError("DEVICE_ID must not be empty")
        if not destination_host:
            raise ValueError("DESTINATION_HOST must not be empty")

        latitude = _read_float("INITIAL_LATITUDE", 35.681236)
        longitude = _read_float("INITIAL_LONGITUDE", 139.767125)
        if not -90.0 <= latitude <= 90.0:
            raise ValueError("INITIAL_LATITUDE must be between -90 and 90")
        if not -180.0 <= longitude <= 180.0:
            raise ValueError("INITIAL_LONGITUDE must be between -180 and 180")

        return cls(
            device_id=device_id,
            destination_host=destination_host,
            destination_port=_read_int(
                "DESTINATION_PORT", 23080, minimum=1, maximum=65_535
            ),
            send_interval_seconds=_read_float(
                "SEND_INTERVAL_SECONDS", 5.0, minimum=0.1
            ),
            response_timeout_seconds=_read_float(
                "RESPONSE_TIMEOUT_SECONDS", 3.0, minimum=0.1
            ),
            initial_latitude=latitude,
            initial_longitude=longitude,
            speed_meters_per_second=_read_float(
                "SPEED_METERS_PER_SECOND", 8.5, minimum=0.0
            ),
            initial_heading_degrees=_read_float(
                "INITIAL_HEADING_DEGREES", 90.0
            )
            % 360.0,
            heading_change_degrees_per_second=_read_float(
                "HEADING_CHANGE_DEGREES_PER_SECOND", 1.0
            ),
        )


class GPSSimulator:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._latitude = settings.initial_latitude
        self._longitude = settings.initial_longitude
        self._heading = settings.initial_heading_degrees
        self._sequence = 0

    def next_sample(self, *, timestamp_ms: int | None = None) -> dict[str, Any]:
        self._sequence += 1
        sample = {
            "device_id": self._settings.device_id,
            "seq": self._sequence,
            "timestamp": timestamp_ms
            if timestamp_ms is not None
            else time.time_ns() // 1_000_000,
            "lat": round(self._latitude, 7),
            "lon": round(self._longitude, 7),
            "speed": self._settings.speed_meters_per_second,
            "role": -1.456,
            "pitch": 250.001,
            "heading": round(self._heading, 2),
        }
        self._advance_position()
        return sample

    def _advance_position(self) -> None:
        distance = (
            self._settings.speed_meters_per_second
            * self._settings.send_interval_seconds
        )
        angular_distance = distance / EARTH_RADIUS_METERS
        latitude = math.radians(self._latitude)
        longitude = math.radians(self._longitude)
        bearing = math.radians(self._heading)

        next_latitude = math.asin(
            math.sin(latitude) * math.cos(angular_distance)
            + math.cos(latitude) * math.sin(angular_distance) * math.cos(bearing)
        )
        next_longitude = longitude + math.atan2(
            math.sin(bearing) * math.sin(angular_distance) * math.cos(latitude),
            math.cos(angular_distance)
            - math.sin(latitude) * math.sin(next_latitude),
        )

        self._latitude = math.degrees(next_latitude)
        self._longitude = (math.degrees(next_longitude) + 540.0) % 360.0 - 180.0
        self._heading = (
            self._heading
            + self._settings.heading_change_degrees_per_second
            * self._settings.send_interval_seconds
        ) % 360.0


class FunnelClient:
    def __init__(self, host: str, port: int, timeout_seconds: float) -> None:
        self._host = host
        self._port = port
        self._timeout_seconds = timeout_seconds
        self._socket: socket.socket | None = None

    def close(self) -> None:
        if self._socket is not None:
            self._socket.close()
            self._socket = None

    def send(self, sample: dict[str, Any]) -> str | None:
        payload = json.dumps(
            sample, ensure_ascii=False, separators=(",", ":")
        ).encode("utf-8")
        udp_socket = self._get_socket()
        try:
            udp_socket.send(payload)
            response = udp_socket.recv(MAX_RESPONSE_BYTES)
        except socket.timeout:
            return None
        except OSError:
            self.close()
            raise
        return response.decode("utf-8", errors="replace").strip()

    def _get_socket(self) -> socket.socket:
        if self._socket is not None:
            return self._socket

        addresses = socket.getaddrinfo(
            self._host,
            self._port,
            family=socket.AF_UNSPEC,
            type=socket.SOCK_DGRAM,
        )
        last_error: OSError | None = None
        for family, socket_type, protocol, _, socket_address in addresses:
            udp_socket = socket.socket(family, socket_type, protocol)
            udp_socket.settimeout(self._timeout_seconds)
            try:
                udp_socket.connect(socket_address)
            except OSError as error:
                last_error = error
                udp_socket.close()
                continue
            self._socket = udp_socket
            logging.info("UDP destination resolved to %s", socket_address)
            return udp_socket

        if last_error is not None:
            raise last_error
        raise OSError(f"No UDP address found for {self._host}:{self._port}")


def run(settings: Settings, stop_event: threading.Event) -> None:
    simulator = GPSSimulator(settings)
    client = FunnelClient(
        settings.destination_host,
        settings.destination_port,
        settings.response_timeout_seconds,
    )
    logging.info(
        "Starting virtual device %s; destination=%s:%d interval=%.1fs",
        settings.device_id,
        settings.destination_host,
        settings.destination_port,
        settings.send_interval_seconds,
    )

    try:
        while not stop_event.is_set():
            cycle_started = time.monotonic()
            sample = simulator.next_sample()
            try:
                response = client.send(sample)
                if response is None:
                    logging.warning(
                        "No UDP response within %.1fs; seq=%d payload=%s",
                        settings.response_timeout_seconds,
                        sample["seq"],
                        json.dumps(sample, separators=(",", ":")),
                    )
                elif is_success_response(response):
                    logging.info(
                        "Sent seq=%d response=%r payload=%s",
                        sample["seq"],
                        response,
                        json.dumps(sample, separators=(",", ":")),
                    )
                else:
                    logging.error(
                        "Funnel rejected seq=%d response=%r payload=%s",
                        sample["seq"],
                        response,
                        json.dumps(sample, separators=(",", ":")),
                    )
            except OSError as error:
                logging.error("UDP send failed for seq=%d: %s", sample["seq"], error)

            elapsed = time.monotonic() - cycle_started
            stop_event.wait(max(0.0, settings.send_interval_seconds - elapsed))
    finally:
        client.close()


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )
    try:
        settings = Settings.from_environment()
    except ValueError as error:
        logging.error("Invalid configuration: %s", error)
        return 2

    stop_event = threading.Event()

    def request_shutdown(signum: int, _frame: object) -> None:
        logging.info("Received signal %d; shutting down", signum)
        stop_event.set()

    signal.signal(signal.SIGTERM, request_shutdown)
    signal.signal(signal.SIGINT, request_shutdown)
    run(settings, stop_event)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
