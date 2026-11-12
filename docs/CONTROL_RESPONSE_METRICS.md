# Interval Tracking and Command-Step Metrics

Interval analysis evaluates position, velocity, attitude, and angular-rate
tracking on the original NED/body axes. An arbitrary selection boundary does
not identify a command onset or establish the initial and final states of a
step response. Active control-loop applicability is not automatically classified.

## General interval tracking

**Interval tracking (selected window)** is the default. It reports RMSE, MAE,
signed bias, maximum absolute error, standard deviation, P95, IAE, ISE, ITAE,
valid duration, sample count, and segment count. These values reuse the existing
interval tracking calculation, including its masks and time weighting. Their
calculation does not depend on step detection or output settling.

This mode does not calculate rise time, settling time, overshoot, or an
initial-to-final normalized response. Those internal response fields remain
unavailable and are omitted from the interval tracking table and CSV.

The final 20% of the selected observation window supplies an additional
time-weighted mean tracking error over paired valid samples. It is labeled
**Tail mean (r-y)**, not steady-state error. This finite observation does not
establish the infinite-time limit, even when its value is small. The 20%
choice is an implementation rule, not a textbook definition.

Tracking bias retains the actual-minus-reference convention. Tail and
command-step steady errors use reference minus actual. A missing reference
leaves reference-dependent values unavailable; a small observed error is not
suppressed by a command-step detection threshold.

## Detected command-step response

**Detected command-step response** is an explicit option for reviewing changes
between held references. Each supported command response is evaluated
separately, with preceding actual samples supplying its initial condition.
A step during flight can support transient metrics when the response and
required initial/final evidence are observed. A cropped response, continuously
varying reference, or general trajectory does not automatically qualify.

For an isolated step, let `t0` be command time, `y0` initial output, `yss`
steady-state output, and `rss` steady reference. Define

```text
q(t) = (y(t) - y0) / (yss - y0)
```

- **Rise time:** first 90% crossing minus first 10% crossing of `q(t)`.
- **Settling time:** time from `t0` to entry into
  `abs(y(t)-yss) <= p*abs(yss-y0)`, retained afterward. The default `p`
  is 0.02; 0.05 is selectable in this mode.
- **Overshoot:** `100*max(0,max(q(t))-1)`, in percent.
- **Peak time:** elapsed time to the maximum normalized response.
- **Steady-state tracking error:** `lim(t->infinity)[r(t)-y(t)]`.

These definitions follow [Introduction to Control Systems, section 4.3](https://pressbooks.library.torontomu.ca/controlsystems/chapter/4-3-step-response-specifications-definitions/)
and the offset-aware conventions in [MathWorks stepinfo](https://www.mathworks.com/help/control/ref/dynamicsystem.stepinfo.html).
Recorded data cannot establish an infinite observation horizon. FLIP uses a
qualified final-20% mean as a finite-log steady-output estimate. It requires
at least 0.2 s, three evaluation points, continuity, and output variation
within `max(reference tolerance,p*abs(final estimate-initial))`. A settling
time additionally requires a continuous remainder inside the band and at
least 0.2 s after final entry. Unconfirmed values remain unavailable.

The tail tracking-error mean is evaluated separately on paired actual/reference
samples. A steady-error estimate also requires continuity, sufficient duration
and samples, and bounded variation. Otherwise it remains a tail mean marked
with `~`. A constant tracking offset during a ramp does not by itself establish
a settled step response.

## Graph presentation and saved output

In default tracking mode, the four tracking figures display numeric error
summaries beside every axis and a marker at the largest observed absolute
tracking error. The original curves and logged time coordinates are retained.
There are no rise-time, settling-band, or overshoot annotations.

The **Interval Tracking** tab displays RMSE, MAE, bias, maximum error,
standard deviation, P95, tail mean, and status. Integral metrics and valid
duration also remain available in the **Axis Metrics** tab. The numerical
tracking summary is saved in `interval_tracking_metrics.csv`, without
transient-response columns.

Detected-step mode adds blue 10-90% markers and a final-output settling band,
a green confirmed-settling marker, a purple response peak/overshoot marker,
and a paired tail-error bracket when the required values are available.
Attitude traces are unwrapped when necessary so that response landmarks and
curves share one angular branch; the axis label states this conversion.
Click the numeric summary or use **Control response** in the figure menu to
inspect another detected response on the same axis. The **Control Response**
tab and `control_response_metrics.csv` retain the detailed response results.
If no step qualifies, graphs still display the independent tracking summary.

Window mode brings the annotated position graph forward after interval output.
The metric-table window remains available. FIG files preserve annotations,
numeric summaries, response selection, and zoom. PDF exports include graphic
annotations in the selected view. File-only mode saves the same content.

Response timestamps use log-relative seconds. Rise, settling, and peak
durations are elapsed seconds. The selected start is never relabeled as a
logged command step.

## Automatic step detection

This optional mode uses recorded reference samples. Adjacent plateaus must
each last at least 0.2 s. Their medians define initial and final targets;
the first new-plateau sample defines observed command time.

| Channel | Reference tolerance | Minimum command change |
|---|---:|---:|
| Position | 0.01 m | 0.05 m |
| Velocity | 0.01 m/s | 0.05 m/s |
| Attitude | 0.1 deg | 0.5 deg |
| Angular rate | 0.5 deg/s | 2.5 deg/s |

These are detection/qualification choices, separate from textbook definitions.
Reference samples stay within tolerance of each plateau's first sample.
Gaps and nonfinite references separate plateaus. Response observation ends
before the next target change. Original data supplies pre-step context at a
selected boundary.

Automatic mode requires a qualified steady output before normalized step
characteristics are reported. Its unavailable values do not suppress the
independent interval tracking summaries.

## Data validity

The default excessive-gap threshold is
`max(0.25 s,5*median(positive sample steps))`. Missing samples are not used
to invent a threshold crossing or confirmed settling. A peak over incomplete
data is explicitly an observed peak, which may miss an unrecorded excursion.
Tail means use segment-wise time integration rather than bridging gaps.

The implementation uses MATLAB array operations and introduces no additional
runtime product requirement.
