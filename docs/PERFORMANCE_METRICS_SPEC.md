# FLIP Performance Metrics

This document describes the implemented tracking metrics, units, synchronization
rules, numerical integration, and interpretation of the result tables.

## Signals and error convention

For actual value `y` and reference `r` at an actual-signal timestamp `t_i`:

\[
e_i=y_i-r_i.
\]

Positive bias means the actual value is above the reference in the signal's
coordinate convention. Position and velocity use PX4 NED. Euler angles are
calculated in radians and displayed in degrees; angular rates are displayed
in degrees per second. Body-rate rows labeled Roll/Pitch/Yaw represent logged
body-rate channels rather than numerical derivatives of Euler angles.

Quaternions use scalar-first Hamilton order `[w x y z]`.

| Signal | Error unit | IAE | ISE | ITAE |
|---|---|---|---|---|
| Position | `m` | `m*s` | `m^2*s` | `m*s^2` |
| Velocity | `m/s` | `m` | `m^2/s` | `m*s` |
| Attitude | `deg` | `deg*s` | `deg^2*s` | `deg*s^2` |
| Angular rate | `deg/s` | `deg` | `deg^2/s` | `deg*s` |

The entire signal unit is squared for ISE, including any denominator.

## Synchronization and valid segments

Evaluation uses actual-signal timestamps inside the reference time bounds.

- Scalar references use linear interpolation. Finite reference timestamps are
  sorted and duplicate timestamps retain their first value.
- Angular scalar references are unwrapped within finite runs; angular error
  is wrapped with `atan2(sin(e),cos(e))`.
- Vector references use finite runs with a common component-validity mask.
- Quaternion references are normalized and interpolated by shortest-path SLERP.
- Invalid actual/query values are excluded, and segment identifiers separate
  the retained runs used by the metric functions.

Vector and quaternion synchronization also propagate reference-run boundaries.
Scalar synchronization derives boundaries from validity on the actual query
grid. If a reference gap has no actual query sample inside it, the scalar
path can retain adjacent valid query points in the same metric segment.
Analysis does not automatically classify every long timestamp interval as a
gap. The replay layer's 0.25-second pose-gap limit is a separate rule.

For retained segments `S_k=[a_k,b_k]` with at least two distinct timestamps:

\[
T_v=\sum_k(b_k-a_k).
\]

`T_v` is valid integrated duration rather than the full wall-clock span.
Singleton segments do not contribute to integration. Duplicate timestamps are
removed within each segment; decreasing valid time is rejected.

Each integral is calculated independently within its supplied segment, using
the nonuniform trapezoidal rule:

\[
I_k(f)=\frac12\sum_{i=1}^{n_k-1}
(t_{i+1}-t_i)(f_i+f_{i+1}).
\]

The implementation applies this rule to the sampled transformed errors, such
as `abs(e)` and `e.^2`. It does not analytically integrate the continuous
square of a piecewise-linear error curve.

## Scalar results

Let `U` denote the signal unit, `a_0=min(a_k)` the earliest retained segment
start, and `tau=t-a_0`.

| Result | Implemented expression | Unit |
|---|---|---|
| Mean bias | \(\sum_k I_k(e)/T_v\) | `U` |
| MAE | \(\sum_k I_k(\lvert e\rvert)/T_v\) | `U` |
| RMSE | \(\sqrt{\sum_k I_k(e^2)/T_v}\) | `U` |
| Maximum absolute error | \(\max_i\lvert e_i\rvert\) | `U` |
| Standard deviation | \(\sqrt{\sum_k I_k((e-\bar e)^2)/T_v}\) | `U` |
| IAE | \(\sum_k I_k(\lvert e\rvert)\) | `U*s` |
| ISE | \(\sum_k I_k(e^2)\) | `U^2*s` |
| ITAE | \(\sum_k I_k(\tau\lvert e\rvert)\) | `U*s^2` |

Standard deviation uses the time-weighted population definition without Bessel
correction. Signed bias can cancel across positive and negative errors.
Maximum error is a sampled maximum, so an unobserved spike is not represented.

ITAE measures elapsed time from the first retained valid segment. A later
segment retains that elapsed clock even though the time between segments is
not integrated. For interval analysis, this origin can differ slightly from
the requested start if the first valid synchronized sample occurs later.

For the same samples and segments:

\[
IAE=MAE\,T_v,\qquad ISE=RMSE^2\,T_v,\qquad
RMSE^2=\bar e^2+\sigma_e^2.
\]

### Time-weighted P95

For a segment with timestamps `t_1,...,t_n`, representative weights are

\[
w_1=(t_2-t_1)/2,\qquad
w_i=(t_{i+1}-t_{i-1})/2,\qquad
w_n=(t_n-t_{n-1})/2.
\]

Across all segments, these weights sum to `T_v`. The absolute errors are
sorted, and P95 is the first value whose cumulative weight reaches
`0.95*T_v`. Result metadata names this method
`weighted empirical inverse CDF`. It is not an unweighted sample percentile.

### Integral magnitude

A constant error of one signal unit over 60 seconds produces MAE and RMSE
of 1, IAE and ISE of 60, and ITAE of 1800 in the appropriate units.
Large integral values therefore do not imply a numerical error. Comparisons
need consistent units, valid durations, and operating conditions.

## Vector metrics

Vector synchronization uses a common timestamp and validity mask for all
required components:

\[
d_{xy}=\sqrt{e_x^2+e_y^2},\qquad
d_p=\sqrt{e_x^2+e_y^2+e_z^2},
\]
\[
d_v=\sqrt{e_{v_x}^2+e_{v_y}^2+e_{v_z}^2}.
\]

Horizontal and 3D position use metres; velocity uses metres per second.
Each magnitude reports mean, RMS, maximum, weighted P95, IAE, and ISE.

Vector coverage can be shorter than any individual-axis coverage. Root-sum-
squaring axis RMSE values equals vector RMS only when masks, timestamps, and
valid duration are identical. The vector rows are calculated from synchronized
vectors rather than assembled from independently evaluated axis summaries.

## Quaternion orientation error

Actual and reference quaternion rows are normalized. Invalid or zero-norm
rows are excluded. The shortest physical orientation difference is

\[
\theta=2\cos^{-1}\!\left(\operatorname{clamp}
(\lvert q_a^\mathsf{T}q_d\rvert,0,1)\right),\quad 0\leq\theta\leq\pi.
\]

The absolute dot product accounts for the equivalent orientations represented
by `q` and `-q`. The summary reports mean, RMS, maximum, and weighted P95 angle,
displayed in degrees. A directional bias or integral row is not reported for
this scalar orientation magnitude.

For SLERP, adjacent reference quaternions are normalized, and the second is
negated when necessary to select the shortest path. For interpolation fraction
`alpha` and separation angle `Omega`:

\[
q(\alpha)=
\frac{\sin((1-\alpha)\Omega)}{\sin\Omega}q_0+
\frac{\sin(\alpha\Omega)}{\sin\Omega}q_1.
\]

The result is normalized again. Nearly coincident quaternions use normalized
linear interpolation. Separate finite reference runs are not interpolated
together.

## Metadata and availability

Results retain availability, sample and segment counts, time bounds, valid
duration, units, method, applicability, and warnings. Missing references are
unavailable rather than interpreted as zero commands.

Applicability is `raw`: active controller/reference applicability is not
automatically classified by flight mode. The metric tables express tracking
evidence rather than a composite flight score or causal diagnosis.

Diagnostic quantities such as battery energy, clipping, estimator flags, and
actuator outputs are described separately in
[diagnostic data](DIAGNOSTIC_PLOT_VALIDATION.md).

## Reference cases

The following analytical cases define expected double-precision results.

| Case | Input | Expected result |
|---|---|---|
| Constant error | `t=[0 1 2], e=[1 1 1]` | `Tv=2`; bias/MAE/RMSE/P95/max=1; std=0; IAE=ISE=ITAE=2 |
| Signed error | `t=[0 1 2], e=[-1 0 1]` | bias=0; MAE=0.5; RMSE=std=`sqrt(0.5)`; IAE=ISE=ITAE=1 |
| Two segments | `[0 1]` at error 1; `[10 11]` at error 3 | `Tv=2`; bias=MAE=2; RMSE=`sqrt(5)`; IAE=4; ISE=10; ITAE=32 |
| Irregular constant | `t=[0 0.1 2], e=[1 1 1]` | Mean-type magnitudes remain 1 |
| Vector | `[3 4 0]` | Horizontal and 3D magnitude 5 |
| Quaternion sign | `q_a=-q_d` | Orientation error 0 |
| Quarter turn | Identity versus 90-degree yaw | Orientation error `pi/2` |
| SLERP midpoint | Identity to 180-degree yaw | 90-degree yaw at midpoint |

## Sources

Interval command-step characteristics are defined separately in
[control-response metrics](CONTROL_RESPONSE_METRICS.md). They supplement
the tracking metrics without changing their calculation rules.

- [PX4 Flight Review](https://docs.px4.io/main/en/log/flight_review)
- [PX4 local-position setpoints](https://docs.px4.io/main/en/msg_docs/VehicleLocalPositionSetpoint)
- [NIST RMSE](https://itl.nist.gov/div898/software/dataplot/refman2/auxillar/rms.htm)
- [NIST standard deviation](https://itl.nist.gov/div898/handbook/ppc/section1/ppc132.htm)
- [NIST percentile definitions](https://itl.nist.gov/div898/handbook/prc/section2/prc262.htm)
- [MathWorks trapezoidal integration](https://www.mathworks.com/help/matlab/ref/trapz.html)
- [MathWorks vector norms](https://www.mathworks.com/help/matlab/ref/vecnorm.html)
- [Graham and Lathrop, time-multiplied absolute error](https://doi.org/10.1109/TAI.1953.6371346)
- [Shuster, attitude representations](https://malcolmdshuster.com/Pub_1993h_J_Repsurv_scan.pdf)
- [MathWorks quaternion SLERP](https://www.mathworks.com/help/aerotbx/ug/quaternion.slerp.html)
