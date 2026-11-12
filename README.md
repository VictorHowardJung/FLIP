# FLIP - Flight Log Interpretation Platform

FLIP analyzes PX4 ULog and MAVLink telemetry logs in MATLAB. It provides
tracking metrics, diagnostic plots, interval re-analysis, and flight
reconstruction through Unreal Engine.

## Requirements

The verified Windows environment is MATLAB R2026a Update 2 with UAV Toolbox
26.1. Flight reconstruction also requires Simulink 26.1 and Simulink 3D
Animation 26.1, with the corresponding licenses available.

FLIP runs in MATLAB. Python and external log-conversion programs are not
required. Simulink replay models are generated from the included MATLAB
source when first needed.

## Run

1. Open the project directory in MATLAB and run `RUNME.m`.
2. Select `1`, **Analyze flight log (.ulg / .tlog)**, and choose a log.
3. Choose the output mode: `1` or Enter opens the plot windows before saving;
   `2` creates and saves the plots without opening result windows.
4. Enter `y` or `Y` followed by Enter to open interval re-analysis, or press
   Enter alone to skip it.
5. Choose `1`, **2D + 3D simulation**, or `2`, **3D only**, for flight
   reconstruction. Press Enter alone to skip reconstruction.

The interval selector remains available independently of the command-window
menu. Reconstruction replays logged poses rather than computing a new
flight response.

## Analysis and saved results

Each analysis produces 15 figures: position, velocity, attitude, angular
rates, motors, battery, IMU vibration, estimator, GPS, control demand, pilot
response, system/link health, performance metrics, tracking errors, and
trajectory views. Missing signals are identified as unavailable. Telemetry
logs may contain fewer references and diagnostics than onboard logs.

In window mode, the metric window appears first. All plots are created
before export. Each figure is saved as an interactive FIG, and a combined
PDF contains one page per figure. Metric PDF pages capture the selected tab
and visible rows; the FIG preserves the complete table.

A session uses the following directories:

```text
results/figures/YYYY-MM-DD/original/
results/figures/YYYY-MM-DD/intervals/interval_STARTs_ENDs/
```

Same-day sessions and repeated interval ranges receive numbered suffixes,
such as `YYYY-MM-DD_002`. Existing outputs are preserved. The command window
prints each saved path. Generated files and raw logs are ignored by Git.

## Interval re-analysis

Choose **Pick start**, then click the overview at the start and end.
**Pick end** changes only the end. Clicks snap to logged position timestamps;
green and orange markers show the boundaries. The time fields also accept
direct input. Esc exits picking while retaining the selected times.

Enter a label and choose **Add & analyze**. The status area shows calculation,
plotting, FIG/PDF export, elapsed time, and completion. Controls are locked
while processing and restored afterward. Window mode brings the completed
interval's annotated position graph forward; the metric table remains
available. File-only mode reports the saved path.

Saved interval definitions can be analyzed, split, merged, or deleted.
Merging requires touching or overlapping ranges. Every interval uses the
same analysis pipeline as the full flight, with time relative to log start.

The default **Interval tracking (selected window)** mode displays RMSE, MAE,
bias, maximum error, standard deviation, P95, and IAE/ISE/ITAE beside the
position, velocity, attitude, and angular-rate curves. A marker identifies the
largest observed absolute tracking error. The **Interval Tracking** tab and
`interval_tracking_metrics.csv` retain the numerical results. This mode does
not calculate rise time, settling time, or overshoot for an arbitrary interval.

The final-20% mean error is labeled **Tail mean (r-y)**. It describes the
observed tail and does not establish steady state. Missing references leave
reference-dependent results unavailable.

Choose **Detected command-step response** to review a recorded target step
with sufficient initial and final observations. Only this mode evaluates
10-90% rise time, +/-2% or +/-5% settling time, and overshoot. Unconfirmed
values remain unavailable without suppressing interval tracking metrics.
Graph landmarks, the **Control Response** tab, and
`control_response_metrics.csv` retain the supported response results.

## Flight reconstruction

Option 1 displays two trajectory plots beside a 1920-by-1080 Unreal camera
image in one MATLAB window. Both panels use the rendered frame's timestamp.
Option 2 opens the standalone Simulink/Unreal viewer.

Analysis plots retain logged North-East-Down coordinates. Reconstruction
uses a fixed frame at the first valid position: Forward defaults to North,
Right to East, and Up to local vertical. Aircraft heading changes the vehicle
attitude while the trajectory axes remain fixed. The upper trajectory is
Right-Up; the lower is Right-Forward. Programmatic calls can set a constant
`ViewHeadingDegrees`, with North=0 and East=90.

The synchronized player provides play/pause/stop, restart, frame stepping,
exact-time seek, a timeline slider, 0.25x to 4x playback, and navigation between
logged state events. The normal synchronized workflow requests up to 15
frames per second; standalone preparation uses up to 60. Display throughput
depends on the graphics hardware, scene, and other open figures.

Both modes use the Epic rendering profile by default. Camera frames retain
Full HD resolution with bilinear display scaling. The Airport scene supplies
an illustrative visual reference; the reconstruction is not recorded flight
video or an independently measured flight site.

Models are generated automatically under `models/` and `results/exports/`.
The standalone model can also be generated explicitly:

```matlab
setup;
buildSimulinkUnrealReplayModel;
```

## Metric interpretation

Tracking errors use `actual - setpoint`. Tail and steady-response errors
use `setpoint - actual`. Reference values are synchronized to actual
timestamps using linear interpolation for scalar/vector signals and
shortest-path quaternion SLERP for orientation.

Axis results include bias, MAE, RMSE, standard deviation, P95, maximum error,
IAE, ISE, and ITAE. Spatial results cover horizontal/3D position, 3D velocity,
and quaternion orientation error. Integral metrics depend on duration and
carry integral units; values in the thousands can be mathematically valid.

Validity masks and segment identifiers govern integration. FLIP reports raw
tracking evidence without automatically classifying the active control loop
or assigning a composite flight score.

## Source and documentation

| Location | Purpose |
|---|---|
| `RUNME.m`, `setup.m` | Workflow, paths, and license checks |
| `src/io` | Log ingestion and output directories |
| `src/preprocessing` | Time, attitude, synchronization, and logged states |
| `src/analysis`, `src/metrics` | Full-flight and interval calculations |
| `src/visualization` | Plot windows, interval selection, FIG/PDF export |
| `src/reconstruction` | Replay preparation and Simulink/Unreal rendering |

- [Metric definitions, units, and reference cases](docs/PERFORMANCE_METRICS_SPEC.md)
- [Interval tracking and command-step metrics](docs/CONTROL_RESPONSE_METRICS.md)
- [Diagnostic data and provenance](docs/DIAGNOSTIC_PLOT_VALIDATION.md)
- [Flight reconstruction and coordinate conversion](docs/FLIGHT_RECONSTRUCTION_DESIGN.md)

FLIP uses the [MIT License](LICENSE). MATLAB, MathWorks toolboxes, PX4, and
Unreal-related products remain subject to their respective licenses.
