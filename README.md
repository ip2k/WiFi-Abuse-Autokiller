At a cafe I frequent, people aren't very considerate of other wifi users.  I usually sit there and code and browse blogs and news, but some people like to watch Netflix, Youtube, Amazon Prime streaming, and basically do other stupid high-bandwidth things.  I should note that this cafe usually has at least 20 people with laptops, and we're all sharing a ~6mbit DSL connection with about 128K upload (as in about 1/8th of one mbit).

When people at this cafe watch videos, it sucks for everyone.  The internet there is already stupid slow with that many people just browsing Facebook.  When you add video streams to the mix, it becomes unusable.  Normal ping times to my current place of employment (about 30 miles away) are in the neighborhood of 2,000-5,000ms.  When I press a single key in an SSH session to my co-located server, it takes a few seconds for that to show up on screen.  This makes coding on a remote box or trying to debug basically anything impossible.

Of course, I like to implement solutions when I have a computer problem, and this is very much a computer problem.  The solution is the awesome [Aircrack-ng][1] suite of tools.  I used to be quite a bit more involved in the Aircrack-ng community (testing beta software, helping with driver issues, helping in IRC, etc), but there hasn't been much new interesting stuff happening there in a while.

First, we need to identify who is abusing their free internet access.  To do that, we'll use [Airodump-ng][2] to inspect the network.  We need to be able to parse the output, so we'll write out a CSV file.  There is actually another step before this (putting the interface into monitor mode or using patched WiFi drivers) which ***should be*** automatic, but is otherwise [left as an exercise to the reader][3] (you'll need to go through that stuff and modify this script a bit if you're using an Atheros chipset and/or the excellent [MadWiFi][4] drivers).
(( If you're having [driver][5] problems, I feel bad for you son, I got 99 chipsets [but Broadcom ain't one][6] ))

Next, we need to parse our CSV and grab the MAC of clients who are being stupid.  We'll set the "stupidity" threshold based on packet count over a defined period (I picked 5 seconds, you might need to play with this a bit).  I picked 50 packets over a 5 second period as my threshold (again, YMMV -- is easy to change).  We use some fun AWK to get this info, then launch [Aireplay-ng][7] to [inject][8] our deauth frames, and we'll also go ahead and spoof the MAC of the base station, because connected clients tend to ignore deauth frames not coming from there.

For added fun, you can run this on a cycle every few minutes:
```bash
while true; do sudo wifi-autokiller.sh; sleep $(($RANDOM / 50)); done
```

Most users will eventually just stop being stupid or leave in frustration, which I'll also consider a win for us in this case.

This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

[1]: http://www.aircrack-ng.org
[2]: http://www.aircrack-ng.org/doku.php?id=airodump-ng
[3]: http://www.aircrack-ng.org/doku.php?id=airmon-ng&s[]=monitor&s[]=mode
[4]: http://madwifi-project.org/
[5]: http://www.aircrack-ng.org/doku.php?id=compatibility_drivers&s[]=injection
[6]: http://www.aircrack-ng.org/doku.php?id=injection_test&s[]=injection
[7]: http://www.aircrack-ng.org/doku.php?id=aireplay-ng
[8]: http://www.aircrack-ng.org/doku.php?id=injection_test&s[]=injection