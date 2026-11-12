# FLIP Flight Reconstruction

FLIP reconstructs recorded position and attitude through the Unreal Engine
runtime provided by the MathWorks 3D simulation products. The motion comes
from the log; the scene, camera, and vehicle mesh provide a visual reference.

## Replay modes

The reconstruction menu contains:

| Option | Display | Entry function |
|---|---|---|
| `1. 2D + 3D simulation` | Two trajectory plots and Unreal RGB in one MATLAB window | `createSimulinkReplayPlayer` |
| `2. 3D only` | Standalone Simulink/Unreal viewer | `runSimulinkUnrealReplay` |

The menu terms describe log replay. The renderer does not compute a new
closed-loop flight response from a controller or vehicle-dynamics model.

The synchronized player supports play, pause, stop, restart, frame stepping,
exact-time entry, a timeline slider, 0.25x/0.5x/1x/2x/4x rates, and navigation
between logged state events.

## Coordinate frames

Analysis plots retain the logged North-East-Down frame and local-position
origin. Their Down axis increases downward.

Reconstruction uses a fixed presentation frame based on the first valid
position and a constant view heading `alpha`. For displacement from that origin:

\[
F=\cos(\alpha)\Delta N+\sin(\alpha)\Delta E,\qquad
R=-\sin(\alpha)\Delta N+\cos(\alpha)\Delta E,\qquad
U=-\Delta D.
\]

The default heading is North=0 degrees, so Forward is North and Right is East.
`ViewHeadingDegrees` selects another fixed heading; East is 90 degrees.
Aircraft yaw changes the vehicle attitude without rotating the path axes or
the virtual operator location.

The frame is a presentation basis, not a continuously moving body frame.
The upper plot shows Right versus Up; the lower plot shows Right versus
Forward. Both use metres and equal distance scales.

PX4 attitude uses body FRD and scalar-first Hamilton quaternions.
The Unreal vehicle input receives:

```text
Position: [Forward, -Right, Up + ground clearance] + scene offset
Rotation port order: [yaw, pitch, roll] in radians
Rotation values: [-(yaw - view heading), -pitch, roll]
```

Relative yaw is wrapped to the principal interval. The renderer's rotation
convention stays right-handed even though FRU is a left-handed presentation
basis.

## Time and data validity

Pose preparation uses a uniform grid adjusted to include the exact source
stop time. The normal synchronized workflow requests at most 15 frames/s;
standalone preparation requests at most 60 frames/s. Playback pacing targets
one log second per real second. Prepared sampling and achieved display rate
are separate quantities.

Position uses linear interpolation and attitude uses shortest-path SLERP.
The default maximum interpolation gap is 0.25 seconds. Nonfinite poses and
larger pose gaps do not form a continuous rendered path. Invalid vehicle poses
are moved off-scene and marked unavailable in the player.

A first or last pose can be held to a log boundary only within the configured
gap threshold. Engine initialization and seek holds do not extend displayed
log time. Nearest-frame selection clips to the replay bounds and selects the
earlier frame when two frames are equally close.

## Ground and propellers

The first valid position supplies the illustrative ground reference.
Relative altitude is clamped to zero below that surface. Logged landed or
ground-contact state also grounds the vehicle. A 0.10 m mesh-origin clearance
keeps the built-in quadrotor geometry above the surface.

The 17-part vehicle model includes four rotor transforms. Their visual angular
speed follows normalized motor commands while armed and freezes after disarm.
Logged `actuator_armed` state has priority; motor activity supplies an arming
fallback when available. Without either source, rotors remain stopped.
Rotor animation does not measure ESC RPM, thrust, or physical motor response.

## Camera and scene

The default scene is Airport. A `[5000, 0, 0]` m offset places the vehicle and
camera over its runway while preserving their relative geometry.

The default operator camera is framed from the full position bounds, behind
the minimum Forward coordinate and centered across Right. It looks along the
fixed Forward direction toward the trajectory's height range. Camera placement
does not use aircraft heading or a measured human-operator position.

The synchronized camera produces 1920-by-1080 RGB. Optical magnification is
limited by the complete logged trajectory and vehicle bounds. The MATLAB
window opens maximized, with a 1:3 split between trajectory and 3D panels.
Bilinear scaling fits the full-resolution image to the available panel.

## Rendering profile and execution order

The default graphics profile is `epic`. Programmatic calls accept `low`,
`medium`, `high`, `epic`, and `cinematic`. R2026a supports configuration through
`World.GraphicsQuality` in a Simulation 3D Actor initialization script.

| Block | Priority |
|---|---:|
| Rendering profile setup | -3 |
| Synchronized pose source | -2 |
| UAV vehicle | -1 |
| Scene | 0 |
| Propeller transform | 1 |
| Camera | 2 |

Vehicle and propeller order determines the body transform presented to the
renderer. The camera samples after the scene update.

The synchronized path uses two seconds of hidden startup frames and a
six-frame target hold for resident seeking. RGB and its associated log time
are published as one latest-frame packet. The display timer consumes that
packet for both panels; state and timeline controls refresh separately.
Old images do not accumulate in a display queue.

## Models and interfaces

| Function or file | Responsibility |
|---|---|
| `prepareUnrealReconstruction` | Resampling, origin, operator frame, and valid pose segments |
| `prepareSimulinkUnrealReplay` | Vehicle/part inputs, ground handling, and camera bounds |
| `buildSimulinkUnrealReplayModel` | Reproducible Simulink model construction |
| `createReplayFrameSource` | Log-frame selection on the running engine clock |
| `flipReplayPoseSource`, `flipReplayFrameSink` | Pose delivery and RGB/time delivery |
| `createSynchronizedReplayViews` | Shared-time trajectory and camera display |
| `fitReplayCameraIntrinsics` | Field-of-view and flight-envelope framing |
| `models/FLIP_UnrealReplay.slx` | Generated standalone model |
| `results/exports/FLIP_SynchronizedReplay.slx` | Generated synchronized camera model |

Both models are generated from the MATLAB source when needed. Generated
models are kept locally. To create the standalone model explicitly:

```matlab
setup;
buildSimulinkUnrealReplayModel;
```

## Interpretation

The Airport scene is illustrative and the origin is derived from logged
position. Logged estimator pose is not external ground truth. Static review
plots use NED, while reconstruction uses the fixed operator frame described
above. Interval analysis operates in its own MATLAB selector rather than
through a reconstruction Mark In/Out workflow.

Frame rate and startup time depend on the machine, scene, graphics profile,
and other active graphics windows.
