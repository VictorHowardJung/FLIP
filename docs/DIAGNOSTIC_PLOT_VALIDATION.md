# FLIP Diagnostic Data and Provenance

Diagnostic plots combine logged values, explicit conversions, derived
quantities, and time associations. Their provenance identifies which of these
operations produced each displayed signal.

## Evidence classes

| Class | Meaning |
|---|---|
| Direct | A named recorded topic field |
| Converted | A recorded field with a stated unit or reference conversion |
| Derived | A calculation from named source fields |
| Association only | Independently sampled quantities displayed together without a tracking or causal claim |

A diagnostic FIG stores a `FLIPDataProvenance` table and offers
**View Data Provenance...**. Its fields describe the signal, topic, instance,
source field, unit, operation, evidence class, and validation.
Unavailable data is identified rather than filled with fabricated measurements.

## Topic and instance selection

ULog ingestion selects one estimator instance using the last finite
`primary_instance` from `estimator_selector_status` when that instance exists.
The IMU-status instance is matched to the selected estimator's accelerometer
device ID. This is a single-instance selection, not a time-varying merge of
all estimator instances.

Other optional multi-instance topics generally use instance 0 when available.
Provenance exposes the selected instance. Raw enums and bitmasks remain
numeric where firmware-specific interpretation is uncertain.

TLOG ingestion converts the supported common MAVLink pose/target messages.
Other telemetry message types are not converted into FLIP diagnostic signals,
even if their names appear in the recorded topic catalog.

## Diagnostic groups

| Group | Recorded or calculated information |
|---|---|
| Motors | Normalized motor commands and final output channels with verified parameter mapping |
| Battery | Pack voltage/current, electrical power, integrated energy, charge, and warning flags |
| IMU | Vibration, coning, clipping counts, and inter-sensor consistency |
| Estimator | Innovations, test ratios, accuracy, resets, and numeric status flags |
| GPS | Fix type, satellites, EPH/EPV, DOP, noise, jamming, and interference |
| Control demand | Thrust/torque setpoints, magnitudes, and control-state context |
| Pilot response | Manual input associated with attitude, rates, and thrust demand |
| System/link health | CPU, RAM, RC, radio, telemetry, power rails, and warnings |

Motor output is a flight-controller command, not measured motor RPM or thrust.
Without a verified output-function mapping, channels are not silently labeled
as particular motors. Pilot/response co-variation is association rather than
a closed-loop system-identification result.

## Derived quantities

- Electrical power is `voltage_v * current_a`.
- Battery energy accumulates trapezoidal power integrals divided by 3600.
  An interval contributes only when both endpoint powers are finite and its
  positive time step is within `max(1, 5*median(positive steps))` seconds.
- Vector magnitude is `sqrt(x^2+y^2+z^2)`.
- Multi-axis clipping is the sum of the recorded X/Y/Z clipping columns.
- Recorded CPU and RAM fractions are displayed as percentages.

Energy reflects the available recorded interval and is not a battery-health
grade. A cell-equivalent voltage inferred from pack voltage and cell count is
not an independently measured per-cell channel.

## Time and display

Signal clocks are normalized to log-start-relative seconds. Independent sample
rates remain visible; placing two quantities on the same time axis does not
imply that one is a setpoint for the other.

Flight-mode shading uses the PX4 Flight Review palette. Time-axis wheel zoom
changes X limits while preserving the plotted signal values. Diagnostic
provenance and PDF export menus are retained in saved FIG files.

## Interpretation

Use diagnostic evidence together with the actual/reference metrics and the
logged state timeline. A plausible numeric range is not proof of correctness.
Estimator flags, power warnings, or clipping events retain their logged
meaning; FLIP does not automatically turn them into a causal diagnosis.

[Metric definitions](PERFORMANCE_METRICS_SPEC.md) provide the associated calculation rules.
