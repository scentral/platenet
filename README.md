# PlateNet CAD/MDT for FiveM

PlateNet brings your CAD/MDT directly into FiveM with a built-in tablet interface.

No additional FiveM resource dependencies are required.

---

## Installation

### 1. Install the resource

Place the resource in your server's resources folder.

The folder **must** be named exactly:

```text
platenet
```

Do not rename the resource folder.

### 2. Start PlateNet

Add PlateNet to your server startup configuration after completing the API key setup at the bottom of this README.

---

## Opening the Tablet

Use:

```text
/platenet
```

or press:

```text
F6
```

The default key can be changed in `config.lua`.

---

## Pairing Your Account

The first time you open the tablet, PlateNet will show a **12-digit pairing code**.

1. Sign in to PlateNet.
2. Open **Device**.
3. Enter or authorize the 12-digit code shown in FiveM.
4. Complete the pairing.

Once approved, the tablet is ready to use.

---

## Moving or Resizing the Tablet

Use:

```text
/platenet set
```

This opens the tablet layout controls.

From there you can:

- move the tablet on screen
- increase its size
- decrease its size
- reset the layout

Your layout settings are saved locally.

---

## Configuration

Basic resource settings are available in:

```text
config.lua
```

You can change settings such as the tablet key and other user-configurable options there.

Resource permissions for third-party plate scanner or ALPR integrations are available in:

```text
server/security.lua
```

---

## PlateNet API Key

Before starting the resource, generate an API key from PlateNet.

Add the following to your `server.cfg`:

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

with the API key generated for your PlateNet community.

Keep the resource name as:

```text
platenet
```

Then restart the resource or server.

---

## Quick Start

```text
Install resource
→ keep folder named platenet
→ add your PlateNet API key to server.cfg
→ ensure platenet
→ use /platenet or F6
→ authorize the 12-digit pairing code
→ done
```

For tablet positioning and size:

```text
/platenet set
```
