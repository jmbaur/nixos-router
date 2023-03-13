start_all()
router.wait_for_unit("systemd-networkd.service")
host1.wait_for_unit("systemd-networkd-wait-online.service")

router.wait_until_succeeds("ping -c 5 host1.home.arpa.")
host1.wait_until_succeeds("ping -c 5 router.home.arpa.")
