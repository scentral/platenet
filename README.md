<div align="center">

# PlateNet CAD/MDT Tablet for FiveM

Bring the PlateNet CAD/MDT browser into FiveM as an in-game tablet.

[![PlateNet Website](https://img.shields.io/badge/PlateNet-platenet.app-111827?style=for-the-badge)](https://platenet.app/)
[![PlateNet Discord](https://img.shields.io/badge/Discord-Join%20PlateNet-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/Mpn6SwhXeW)
[![Contact](https://img.shields.io/badge/Contact-Support-1f2937?style=for-the-badge)](https://platenet.app/contact)

**PlateNet CAD/MDT:** https://platenet.app/

</div>

---

## What this is

This resource opens the PlateNet CAD/MDT inside FiveM as a tablet.

PlateNet itself is the browser-based CAD/MDT. If you have not set up PlateNet yet, check it out here:

**https://platenet.app/**

This FiveM resource has no additional FiveM resource dependencies.

---

## Install

### 1. Add the resource

Place the resource in your server's resources folder.

The folder must be named exactly:

```text
platenet
```

Do not rename it.

### 2. Complete the server setup

Before starting PlateNet for the first time, complete **Appendix A - Server Configuration** at the bottom of this README.

### 3. Start PlateNet

Start or restart your server after adding the configuration from Appendix A.

---

## Open the tablet

In game, use:

```text
/platenet
```

or press:

```text
F6
```

F6 is the default keybind.

You can also change the keybind from FiveM's in-game key binding settings without editing the resource.

---

## Pair your PlateNet account

The first time you open the tablet, it will show a **12-digit pairing code**.

1. Sign in at **https://platenet.app/**
2. Open **https://platenet.app/device**
3. Enter or approve the 12-digit code shown on the FiveM tablet
4. Finish the pairing

Once approved, reopen the tablet if needed and you are ready to use PlateNet.

---

## Move or resize the tablet

Use:

```text
/platenet set
```

This opens the tablet layout controls.

You can move the tablet around the screen, increase or decrease its size, reset the layout, and save the position locally.

---

## Keybinds

The default tablet key is:

```text
F6
```

You can change it in FiveM:

```text
Settings
→ Key Bindings
→ FiveM
→ Open PlateNet
```

The default key can also be changed in `config.lua`.

---

## Need help?

**PlateNet:** https://platenet.app/

**Device pairing:** https://platenet.app/device

**Contact / Support:** https://platenet.app/contact

**Discord:** https://discord.gg/Mpn6SwhXeW

---

# Appendix A - Server Configuration

## Generate your PlateNet API key

Sign in to PlateNet and generate an API key for your community.

Then add the following to your `server.cfg`:

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

with your PlateNet API key.

The resource must remain named:

```text
platenet
```

After saving `server.cfg`, restart the server.

## Basic resource configuration

Open:

```text
config.lua
```

Set your PlateNet community slug and any defaults you want to change.

Example:

```lua
Config.CommunitySlug = 'your-community'
Config.TabletKey = 'F6'
```

The keybind can still be changed by each player through FiveM's in-game key binding settings.
