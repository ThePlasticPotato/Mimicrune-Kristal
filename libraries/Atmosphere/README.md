# Atmosphere

Atmosphere is the ultimate(?) atmospheric effect library- lights, weather, time, footsteps, and more!

## Weather

```lua
Atmosphere:setWeather("rain", false, 2)
Atmosphere:stopWeather(false)
```

The second argument controls whether the transition is instant. The remaining
arguments are passed to that weather's constructor.

### Built-in weather IDs

- `clear`
- `cloudy`
- `overcast`
- `dark_overcast`
- `rain`
- `thunder`
- `snow`
- `wind`
- `chilly`
- `fog`
- `hot`
- `volcanic`
- `cd` / `cats_and_dogs`
- `flipped_rain`
