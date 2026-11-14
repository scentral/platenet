# PlateNet CAD/MDT Tablet for FiveM

https://platenet.app

## For fictional roleplay use only.

---

## Install

### 1. Add the resource

Place the resource in your server's resources folder.

Keep the folder name exactly:

```text
platenet
```

Do not rename it.

### 2. Configure your server

Complete **Appendix A - Server Configuration** at the bottom of this README.

### 3. Start PlateNet

START or RESTART your server after saving the configuration.

---

## Open the tablet

Use:

```text
/platenet
```

or press:

```text
F6
```

You can change the keybind in FiveM:

```text
Settings
→ Key Bindings
→ FiveM
→ Open PlateNet
```

You can also change the default key in `config.lua`.

---

## Pair your account

1. Open the tablet in FiveM.
2. Copy the 12-digit code shown on screen.
3. Sign in at **https://platenet.app/**
4. Open **https://platenet.app/device**
5. Enter or approve the code.
6. Finish pairing.

Once approved, open the tablet and use PlateNet normally.

---

## Report an emergency

Anyone on the server can use this, no tablet pairing is required.

```text
/911 leo <what is happening>
/911 fire <what is happening>
/911 ems <what is happening>
```

Choose a service: `leo`, `fire` or `ems`. The call is refused without
one. Your street and area are attached automatically. One call per
player every 5 minutes by default (`Config.EmergencyCooldownSeconds`).

---

## Signal 100

```text
/panic
```

This is for Patrol Units and Dispatchers only, after a tablet is paired.
Default is one per minute.
(`Config.PanicCooldownSeconds`).

Set either command to `false` in `Config.Commands` to disable it.

---

## Move or resize the tablet

Use:

```text
/platenet set
```

Use the on-screen controls to move the tablet, increase or decrease its size, reset the layout, or finish editing.

---

## Tablet animation

When you open the tablet on foot, your character holds a tablet. In a vehicle there is no animation.

Turn it off for yourself, or back on, with the Animation button in `/platenet set` or:

```text
/platenet anim
```

Turn it off for this server with `Config.TabletAnimation = false` in `config.lua`.

---

## Call alerts

Paired units get a card in the top right of the screen for 15 seconds:

- **NEW CALL** - a call that still needs units, for your department or with no department. Calls a unit
  makes for themselves do not show.
- **PANIC** - every Signal 100, for every unit and dispatcher except the one who raised it.
- **ASSIGNED TO YOU** - you were put on a call. A waypoint is set when the call has a map position.
- **NEEDS A UNIT** - while a dispatcher is on duty, a call nobody picked up in time.

While a dispatcher is on duty, NEW CALL cards do not show; the dispatcher assigns units.

Press **F9** on a card to respond: you are put on the call and a waypoint is set. A Signal 100 takes any
number of units. Other calls take the number of units they need; after that the card says who has it, and
you attach in the tablet. While a dispatcher is on duty, F9 sets the waypoint and the dispatcher assigns
units. Change the key in Settings > Key Bindings > FiveM ("PlateNet: respond to a call").

Turn alerts off for yourself, or back on:

```text
/platenet alerts
```

Turn them off for the community in the Community Panel under **GAME SERVER LINK**, or for this server with
`Config.CallAlerts = false` in `config.lua`.

---

## Player access

Other resources can read a paired player's CAD access: their callsign, whether they have patrol,
dispatch or supervisor access, and their departments.

PlateNet Radio (`platenet-radio`) is allowed by default. Allow any other resource in `server/security.lua` under `PlayerAccess`, using its exact folder name:

```lua
PlayerAccess = {
    ['your_resource'] = true,
},
```

The resource calls:

```lua
exports.platenet:GetPlayerAccess(source, function(data) end)
```

`data.success` is false when the player has not paired their tablet. Otherwise it holds
`callsign`, `unit`, `dispatch`, `supervisor`, `civilian` and `departments` (each with `code`, `service_type` and `primary`).

---

## Help

**PlateNet:** https://platenet.app/

**Device pairing:** https://platenet.app/device

---

# Appendix A - Server Configuration

## Generate your API key

Sign in to PlateNet and generate an API key for your community.

Add this to your `server.cfg`:

```cfg
## PlateNet
set platenet_api_key "YOUR_API_KEY_GOES_HERE"
add_convar_permission platenet read platenet_api_key
add_ace builtin.everyone command.platenet_api_key deny
ensure platenet
```

Replace:

```text
YOUR_API_KEY_GOES_HERE
```

with your PlateNet API key. The key finds your community.

## PlateNet Radio

If you also run PlateNet Radio, add these lines under the PlateNet lines:

```cfg
add_convar_permission platenet-radio read platenet_api_key
ensure platenet-radio
```

## Configure PlateNet

Open:

```text
config.lua
```

Change any defaults you want, then restart the server.
