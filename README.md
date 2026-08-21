<div align="center">

# PlateNet CAD/MDT Tablet for FiveM

[![PlateNet](https://img.shields.io/badge/PlateNet-platenet.app-111827?style=for-the-badge)](https://platenet.app/)
[![Discord](https://img.shields.io/badge/Discord-Join%20PlateNet-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/Mpn6SwhXeW)

</div>

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

## Move or resize the tablet

Use:

```text
/platenet set
```

Use the on-screen controls to move the tablet, increase or decrease its size, reset the layout, or finish editing.

---

## Help

**PlateNet:** https://platenet.app/

**Device pairing:** https://platenet.app/device

**Discord:** https://discord.gg/Mpn6SwhXeW

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

with your PlateNet API key.

## Configure PlateNet

Open:

```text
config.lua
```

Set your community slug:

```lua
Config.CommunitySlug = 'your-community'
```

Change any other defaults you want, then restart the server.
