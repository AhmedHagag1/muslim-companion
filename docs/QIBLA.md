# Qibla V1

## Calculation

The Qibla bearing is calculated locally using the standard initial
great-circle bearing formula. The result is normalized clockwise to `0–360°`
from geographic north. The relative arrow angle is:

`normalized Qibla bearing - normalized device heading`

Kaaba coordinates are `21.4225241, 39.8261818`, matching the open-source
Batoul Apps Adhan implementation already used as a dependency by this project:
https://github.com/batoulapps/adhan-js

The bearing calculation is isolated in `QiblaCalculator` and does not alter or
depend on the application's prayer-time calculation method.

## Compass sensor

`flutter_device_compass` supplies stream-based device heading readings. On
Android it reports a null heading when a usable compass sensor is unavailable.
The application also handles stream errors and a no-reading timeout without
crashing. Sensor subscriptions are active only while the Qibla page is active.

Compass readings can be affected by cases, speakers, vehicles, steel surfaces,
and other magnetic fields. The page provides calm figure-eight calibration and
interference guidance. It does not display an accuracy percentage because the
Android plugin documentation says its error estimate can be hard-coded and is
not sufficiently reliable for that claim.

## Location and privacy

Qibla reuses the same `LocationService` instance as `PrayerController`,
including its established permission, retry, Location Settings, and App
Settings behavior. A concurrent request is shared and the most recent position
is kept in memory only. Qibla does not add background-location permission and
does not persist precise coordinates.

## Offline behavior

Once a current position is available, bearing and relative-angle calculation
are entirely on-device. No remote Qibla API, cloud service, account, or network
connection is used. The magnetometer also operates locally.

## Alignment feedback

Alignment is considered approximate within ±4°. The visual confirmation is
subtle and one selection haptic is issued only when entering that range. It is
not repeated while the device remains aligned and no sound is played.
