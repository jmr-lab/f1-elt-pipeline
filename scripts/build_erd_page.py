#!/usr/bin/env python3
import sys
from pathlib import Path

DEST = Path(sys.argv[1] if len(sys.argv) > 1 else "dbt/target/erd.html")

# Embed URL generated from sqltoerdiagram.com (no account needed)
# Diagram state is encoded in the fragment (#s=...) of the URL
SQLTOERDIAGRAM_EMBED_URL = (
    "https://sqltoerdiagram.com/?embed=1#s=z7Vlbb9s4Fv4rAh8WLSC7Eqmr5ymbuovspJmO4-7OYFoItMTY3MiUhqSSyRT-7wOKEi3JcuwULRYL7KN1LjznO1fSXwAuSzAD2Sqjawxs8EC4oAUDM9cG4vcczMBkYi3IHeGEpcSSeJUTYb1ihfXuR_H6E7tczC-Wc2t58ffruZUWFZOcKoZPzLJoZl3dLOf_mC-sD4ur9xeLX60f57_aiqQ5n5K0yIi1nP-ytG5-Wlo3H6-vu-QRyuVPN7fLxcXVzdKqfk_MgUlP4cebq58_zq1X3Y-vP7HXP3xiQ4s3eFvSgokNLRPxJCTZnrSd4a22uf7FDTbmU8bpA-HJigiZcCKqXAqlrKZJgrfjlEZKECwKlogyp7IvdZxSFpRJkZS1uFDxM3SS0zVd0ZxKjeYoCo38t_K_xFxSnA89KwtBJS1YY-6QfIeFVLjkuBx6Ny5XE8ekxAZzkiW1XvORiiQrqlVOOmpaMCYT6y3dElYjp1N8mCeUpxWV52PTz9oRkPIixSYqB0l_pEgW83fzxfzmcn67r7V-lmvdWFJZZcRazC-0AXnB1oNPOG-YWoQe6T0tSUbx8URZYUEShfv5QIzq0SE_qWQENrxacfJAsUqI_de7gpN-WoqK9z98NZgZliQp7pIV5XJjvb1YznWSE77FjDCZpJgnrNquCH8JlC9D8WQ6fbV7JqSJtqMrZ2ivaKa5S063uJbPC74__Qx_dfc66fETwTWMg3lw2KZHzB3hMob3LRwZJU13rc9v54f6MT43eFGx7KQzjc7G0tajrsmaw1jZtJkx3zTFcA4SjuOUDJOwn_8qjffZS0WSYpaSPCf6qLfzdxcfr5eWc3489aA5WcMKqecgqBmMX_KpHMv4gWuSbomQeFtay6v389vlxfsP5vufBev2gXRDsionmZoQ-9lRz4DjmdQbiMa2E6BtsEiUAUmGJe7TO4PmnxVLVfN6w4lq0zpbx4dOXZVntsoXp1q35MfYe2XfjOhn2DWHEeBFTo5VWtetttKM-XZrmL0_dLwEG5Hvhc-LXW5b60jtmvZ7wpezZsL3jfSZXpwx4-u6JvVG8617xD6BTvnVsO3d683qTlne6nY2yckDyS3JMRO4rlOcjxdn0_-S8zxsuZ-NWs3SKSEFSq3-JDQ1l5Fcc83fdDq9Pfdbn-ishrhU16dtmROp-5peqfaLdcIxu-_13s5YIRLTvNNvJZaV2P9WPTPHQtA7Oto0qUj0FSUnyV3BO8v5Yffs4a8W_nNRPwlij_HYjD1Aso8EfiAcr0kiSkKyHgD6-MFN5RCHjJgInPC9pDIRsvjuAKjYHzaCHJfHIMoqPtjM62tO0pnXnXYxmViXnZXtjZCYZZStxXjFNRXf3fK-fbMc3z-_Yv51OtrRRnayNh8p0y8bY-sGXW9UPt1RRsWme89tC6on5Ookzf5TCblV1xazaY01qGf6Uss53EBrjw976-FG898I4Itm4P-Dd_qtbJ9IJ0PYYR08-Rwm26CMhvXQz4bzVp6RKHcbUME5qQe9eIOrjMpnew-ru1v9bpOke0kNwYubhPEmERJzeW6G78UIOwXE8XfWc98HOrt7eZ9kLO3G13plnLaH7oxvunVknoXxRaX6PwFh_yLeB1QOATXXn2NwTibWB8JwLp_UwFxTtjav8qLYEvUub1UsJVxiyqxHKjdFJa1twYmVFkySP5Sq_jqh1Z0sZII5I9nL1whB-MPXyB2Mx5ymhInuC2478up7d3sOS0o6NjHNvqagBDbIKM5JKsFM_dNBJQE2aI8UYPYF9F4B1Ic_wGwShIENnsBsAuHOBg10hoiimoi8UBGbNa2lwjiuqR7ydzbIcUvwQ_3ZdXY2MG9uDdH1XKgPdAO0s8HII1fLibSeSegHOxvsLwbm_NDRDMhzdzZoQDfUQFs3cSFqxVvNrVykFPeC1Uq3LKFybWRTazVB1OpyFEQHC4HxOmysQY7SqIuhPSw2BjkKss7tueXwY7-JkgZNv57t5ZsYukg5ZGrXhDHyarrrapw6Dw2GBUYdh4-MxoYZ-U0EYayM6SlCPtK0SOnpXFkbeuA0jiCkXH1-Dg1lYgPx8wIRbIxAbivRUqLGzQDulJ94SzhuaF6oj_F8xwYixTkBM2caOTXimLFC6vctMPvtC6AZmAG8ffTWDK69CQQ2UAsomIE1L6oS2DWqCHpTP3a9IIoRjCLo6DhMPBRMYx85AQwc6MLYtcEjmAXQmUZR6EHoR54LUWCDDZiFYTj1YRgGXgAD5KhQq6YHZmCBU2L9m5B7wjKgwp4XvLZqRTjY2V0jOd48TrxRI103Dqa-A2MHOb4XOS10kTd1EYQwiCPfc2KvNtGHzjSAKHT9wAkipAzfgJnv-1PketBzg8jxgo6Jt-0VqGNfWfEyJwMDy4eHfILGUYyROw0VfF4YOgGMmmRHgTf1I98LkRPEQaQSWFnoh1M_QG4U-j7yXKhBDBxffYVh5MSR4weusfAS54RlmFt_s_5FWEU6hq45IWxgZyodPHFH7UQQTSPP9Xw_cMPYd5pMQ74yM_I8ZbtTJ-CjStFwCv3Q8WMnCnykylsBGTpKRQCdGIY-8mNj5pLgbRfEVV4RsPtsgw3NMsLA7Le6Ae87eKddqzHQ7fzdpjzegD_bYItZhfNryu51wt_xoi6iejaDmWlBtUlgBtr__4AquOI5TpqB3e7z7i8"
)

TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Formula1 Data Model</title>
<style>
  html, body { margin: 0; height: 100%; font-family: system-ui, -apple-system, sans-serif; }
  header { padding: 14px 22px; border-bottom: 1px solid #e6e6e6; font-size: 15px; }
  header a { color: #6d4aff; text-decoration: none; }
  iframe {
    display: block;
    width: 100%;
    height: calc(100vh - 50px);
    border: none;
  }
</style>
</head>
<body>
<header><strong>Formula1 Data Model</strong> &nbsp;·&nbsp; <a href="./">← dbt docs</a> &nbsp;·&nbsp; <a href="https://sqltoerdiagram.com">Powered by SQL to ER Diagram</a></header>
<iframe src="__EMBED_URL__" title="Interactive ERD — explore tables and relationships"></iframe>
</body>
</html>
"""

def main():
    DEST.parent.mkdir(parents=True, exist_ok=True)
    DEST.write_text(TEMPLATE.replace("__EMBED_URL__", SQLTOERDIAGRAM_EMBED_URL))
    print(f"Wrote {DEST} ({DEST.stat().st_size} bytes)")

if __name__ == "__main__":
    main()
