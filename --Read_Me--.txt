+++++++++++++ Copyright (c) 2026 scentral ++++++++++++++
++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++ PlateNet CAD/MDT | www.PlateNet.app ++++++++++
++++++++++++++++++++++++++++++++++++++++++++++++++++++++
            https://discord.gg/Mpn6SwhXeW

PlateNet FiveM Installation

1. Generate your API key in PlateNet.

2. Add this to your server.cfg:

## PlateNet
set platenet_api_key "YOUR_API_KEY_GOES_HERE"
add_convar_permission platenet read platenet_api_key
add_ace builtin.everyone command.platenet_api_key deny
ensure platenet

3. Install the PlateNet resource.

Do not change the resource folder name. It must be named:

platenet

4. Open the tablet.

Use:

/platenet

or press:

F6

You can change the tablet key in config.lua.

5. Pair your account.

Open the tablet and use the 12-digit code shown on screen.

Sign in to platenet.app/device, or if you are already signed in, go to platenet.app/device, authorize the code, and pair the device.

Once approved, the tablet is ready to use.

6. Adjust the tablet display.

Use:

/platenet set

From there you can move the tablet and increase or decrease its size.
