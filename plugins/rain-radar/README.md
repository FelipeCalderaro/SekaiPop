# Rain Radar

The rain radar around you as a loop: the last two hours, every 10 minutes, resting a moment on the
newest frame, on a quiet grey map with a pin on your place. From **RainViewer**: no account, no key.

Add it from Edit Desktop's shelf and set **Place** (Settings > Desktop > Plugins > Rain Radar): a
city, looked up once with Open-Meteo's geocoding (the same service the weather card uses), or
`lat, lon`.

- **Zoom** 3 (a continent) to 7 (a region): RainViewer's free radar tiles stop at 7.
- The strip under the map is the frames; click one to stop on it. Forecast frames, when RainViewer
  has them, are hollow. The chip says the frame's time and how long ago it was.
- It fetches the frame list every 10 minutes and plays only while it is on screen. Every frame's
  tiles stay loaded, so the loop doesn't flicker; that is up to ~13 x 9 small pictures.
- Radar colours: Universal blue, The Weather Channel, NEXRAD, Dark sky.

Map tiles: Esri's World Light / Dark Gray Canvas (light or dark with your card), credited under the
map as Esri asks. (CARTO's basemaps now need an API key, so they aren't used.)

Files: `Service.qml` (place and frames), `Widget.qml`, `Radar.js` (tile maths, URLs, words; pure),
`kit/`. Tests: `sh sekaipop/tests/plugin-widgets-test/run.sh rain-radar`.
