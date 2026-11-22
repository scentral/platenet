# PlateNet CAD/MDT

> **Update: 11/22/2026**
>
> PlateNet downloads have been moved from GitHub to the **Community Owner Admin Panel** at [platenet.app](https://platenet.app).
>
> All future downloads, version updates, and feature updates will be available there.

A CAD/MDT tablet for FiveM, connected to your community at
[platenet.app](https://platenet.app). Pair a PlateNet account to use the tablet
in-game. Players can also report emergencies without pairing.

For fictional roleplay use only.

## Install

1. Put the resource in your server's `resources` folder. The folder must be named
   `platenet`; don't rename it.
2. Sign in at [platenet.app](https://platenet.app) and generate an API key for
   your community.
3. Add the following to `server.cfg`, replacing `YOUR_API_KEY_GOES_HERE` with
   your key:

```cfg
## PlateNet
set platenet_api_key "YOUR_API_KEY_GOES_HERE"
add_convar_permission platenet read platenet_api_key
add_ace builtin.everyone command.platenet_api_key deny
ensure platenet
```

Start or restart the server after saving the configuration. Other defaults are
in `config.lua`.

**PlateNet Radio:** If you also use `platenet-radio`, add these lines below the
PlateNet configuration in `server.cfg`:

```cfg
add_convar_permission platenet-radio read platenet_api_key
ensure platenet-radio
```

## Open and pair the tablet

Use `/platenet` or press **F6**. The default key can be changed in `config.lua`,
or in FiveM under **Settings > Key Bindings > FiveM > Open PlateNet**.

To pair your account:

1. Open the tablet in FiveM and copy the 12-digit code.
2. Sign in at [platenet.app](https://platenet.app).
3. Open [platenet.app/device](https://platenet.app/device) and enter or approve
   the code.
4. Once approved, open the tablet again.

## Emergency calls

Anyone can report an emergency, even without a paired tablet:

```text
/911 leo <what is happening>
/911 fire <what is happening>
/911 ems <what is happening>
```

The service (`leo`, `fire`, or `ems`) is required; calls without one are refused.
The player's street and area are attached automatically. By default, each
player can make one call every five minutes
(`Config.EmergencyCooldownSeconds`).

## Signal 100

Patrol units and dispatchers with a paired tablet can raise a Signal 100:

```text
/panic
```

The default cooldown is one minute (`Config.PanicCooldownSeconds`). You can
disable `/911` or `/panic` by setting the corresponding command to `false` in
`Config.Commands`.

## Call alerts

Paired units see call cards in the top-right corner for 15 seconds.

| Alert | When it appears |
|---|---|
| **NEW CALL** | An unassigned call for your department, or one without a department. You won't see a call you made yourself. These cards are hidden while a dispatcher is on duty. |
| **PANIC** | A Signal 100, shown to every unit and dispatcher except the person who raised it. |
| **ASSIGNED TO YOU** | You've been assigned to a call. A waypoint is set if the call has a map position. |
| **NEEDS A UNIT** | A call hasn't been picked up in time while a dispatcher is on duty. |

Press **F9** on a card to respond. Without a dispatcher on duty, this attaches
you to the call and sets a waypoint. Signal 100 calls can take any number of
units. Other calls accept only the number of units requested; once full, the
card shows who's handling the call, and you can attach through the tablet.

While a dispatcher is on duty, **F9** sets the waypoint, but the dispatcher
handles unit assignments. To change the response key, open **Settings > Key
Bindings > FiveM > PlateNet: respond to a call**.

Turn alerts on or off for yourself with:

```text
/platenet alerts
```

Community-wide alerts can be disabled in the Community Panel under **GAME
SERVER LINK**, or on this server with `Config.CallAlerts = false` in
`config.lua`.

## Tablet settings

| Command | What it does |
|---|---|
| `/platenet set` | Move or resize the tablet, reset its position and size, or finish editing. |
| `/platenet anim` | Toggle the tablet-holding animation for yourself. |
| `/platenet alerts` | Toggle call alerts for yourself. |

The tablet animation plays when you open it on foot, but not in a vehicle.
You can also toggle it using the **Animation** button in `/platenet set`.
To turn it off for the whole server, set `Config.TabletAnimation = false` in
`config.lua`.

## Player access for other resources

Other resources can read a paired player's CAD access, including their
callsign, role permissions, and departments. `platenet-radio` is allowed by
default. For other resources, add their exact folder name under `PlayerAccess`
in `server/security.lua`:

```lua
PlayerAccess = {
    ['your_resource'] = true,
},
```

Call the export from the allowed resource:

```lua
exports.platenet:GetPlayerAccess(source, function(data)
    -- Handle the returned access data.
end)
```

`data.success` is `false` if the player hasn't paired their tablet. Otherwise,
the response includes:

| Field | Contents |
|---|---|
| `callsign` | Player's callsign |
| `unit`, `dispatch`, `supervisor`, `civilian` | Access fields returned by PlateNet |
| `departments` | Department entries with `code`, `service_type`, and `primary` |

## Configuration

Edit `config.lua` and restart the server after changing defaults.

| Setting | Purpose |
|---|---|
| `Config.Commands` | Disable `/911` or `/panic` by setting the corresponding command to `false` |
| `Config.EmergencyCooldownSeconds` | Time between emergency calls per player; default 300 seconds |
| `Config.PanicCooldownSeconds` | Time between Signal 100 uses; default 60 seconds |
| `Config.CallAlerts` | Enable or disable call alerts for this server |
| `Config.TabletAnimation` | Enable or disable the tablet-holding animation for this server |

The default tablet key can also be changed in `config.lua`. Individual players
can change their keybinds and toggle alerts or animation in-game.

> **Update: 11/22/2026**
>
> PlateNet downloads have been moved from GitHub to the **Community Owner Admin Panel** at [platenet.app](https://platenet.app).
>
> All future downloads, version updates, and feature updates will be available there.

## Links

- **PlateNet:** [platenet.app](https://platenet.app)
- **Device pairing:** [platenet.app/device](https://platenet.app/device)
