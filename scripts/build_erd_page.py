#!/usr/bin/env python3
import sys
from pathlib import Path

DEST = Path(sys.argv[1] if len(sys.argv) > 1 else "dbt/target/erd.html")

# Embed URL generated from sqltoerdiagram.com (no account needed)
# Diagram state is encoded in the fragment (#s=...) of the URL
SQLTOERDIAGRAM_EMBED_URL = (
    "https://sqltoerdiagram.com/?embed=1#s=z7Vlbb9s4Fv4rAh8GLSC7FHX3PmVTd5GdNNN13NkdTAuBlhibG5nSkFTSbOH_PqBIyZIsx07RYrHAPlrnHPI7H8-N9FeAyxLMQLbK6BoDGzwQLmjBwMyxgfgjBzMwmVgLckc4YSmxJF7lRFivWGG9-1m8_sQuF_OL5dxaXvz1em6lRcUkp0rhE7MsmllXN8v53-YL68Pi6v3F4jfr5_lvthJpzackLTJiLef_Wlo3vyytm4_X113xiOTyl5vb5eLi6mZpVX8k7YZJb8GPN1f_-Di3XnU_vv7EXv_lExsi3uBtSQsmNrRMxJOQZHsSO8Nbjbn-xVtu2k8Zpw-EJysiZMKJqHIp1GK1TBK8HZcYK0GwKFgiypzKvtVxSVlQJkVS1uZCnV8rJzld0xXNqdRsjrJg7L-X_yXmkuJ86FlZCCppwQzcofgOC6l4yXE59G7crhaOWYkN5iRL6nXbj1QkWVGtctJZpiFjMrHe0i1hNXM6xIdxQnlaUXk-N_2oHSEpL1LcnspB0B9JksX83Xwxv7mc3-5zrR_lem0sqawyYi3mFxpAXrD14BPOjVLD0CO9pyXJKD4eKCssSKJ4P5-I0XX0kZ9cZIQ2vFpx8kCxCoj917uCk35Yior3P3wzmRmWJCnukhXlcmO9vVjOdZATvsWMMJmkmCes2q4IfwmVL2PxZDh9s3vtkSYaR9eulb2imdYuOd3i2j4v-H73M_zV1eukx08E1zQO-sFhmR6BO6LVAu8jHGklprrW-zf9Q_0Y7xu8qFh20hmzpkHaeNSFrDValKbMjPmmJa3mIOA4TskwCPvxr8J4H71UJClmKclzord6O3938fF6acHzz1M3mpM5rJh6joJaofVLPpVjET9wTdItERJvS2t59X5-u7x4_6H9_p-CdetAuiFZlZNMdYh976h7wPFI6jXEFtsJ0jZYJApAkmGJ-_JOo_l7xVJVvN5wosq0jtbxplNn5Zml8sWh1k35MfVe2psW_Yy61mgNeJGTY5nWdavJtBa-3QCz95uOp6Ax-VH8vNjlprSO5G5bfk_4clZP-LEnfaYXZ_T4Oq9JPdF87xqxD6BTfhm1vXu9Xt1Jy1tdziY5eSC5JTlmAtd5ivPx5DT1LznPw0b72VOrVToppEiplz9JTa3VWq651jeVTk_P_dInOqMhLtX1aVvmROq6pkeq_WCdcMzue7W301aIxDTv1FuJZSX2v1XNzLEQ9I6OFk0qEn1FyUlyV_DOcH5YPXv8q4H_XNZPkthTPNZjD5jsM4EfCMdrkoiSkKxHgN5-cFM55CEj7Qmc8L2kMhGy-OEEqLM_LAQ5Lo9RlFV8MJnX15yk06875WIysS47I9sbITHLKFuL8YwzGd-d8r5_sRyfP7-h_3Uq2tFCdjI3HynTLxtj4wZdb1Q83VFGxaZ7z20Sqmfk6CDN_l0JuVXXlnbSGitQz9SlRnM4gdYeH9bWw4nmv3GAL-qB_z-8029l-0A6eYQd1cGTz2GwDdJomA_9aDhv5Bk55W4BKjgndaMXb3CVUfls7WF1davfbZJ0b6kpeHGRaL1JhMRcnhvhezPCThFx_J313PeBzuxe3icZS7vna71qnbaH7oxPuvXJPEvji1L1f4LC_kW8T6gcEtpef47ROZlYHwjDuXxSDXNN2bp9lRfFlqh3eatiKeESU2Y9UrkpKmltC06stGCSfFFL9ccJvdzJRCaYM5K9fIwQhD98i91Be8xpSpjovuA2La--dzf7sKSkYx2zndcUlcAGGcU5SSWYqX86qCTABs2WAsy-gv1orX59AbMJClwbPIHZxA3CnQ0McY00MrIY7mxtbCQoRlrkOb4y674uNMYOcn2jFDo7G4w8ZnVUQ60a-mqrg67aKAZebPQitLPByADVaMYu1Jp-pFY059FIXegZqaeQNaFuxA4KDRw3UPLexbzRcR3HQPEUBeY5y0jjwLjuO-5-AeVWYw7Dxtx3Wg0jDB2DPYjivZdHakyLx9dbugpNdyfPMYIa53PlqrFwvKC2QDDa2aB9M23ZcTR5nqfI6bESG17d2vJIfzW6gWEAueooO3fbZi1PsxCopZoLQhN_gUY4cVDndHW2NWfsNyr1-jlubF2k1429ncKIt4TjBpJnPIvUn4UpzgmYwakXOgoCZqyQ-oELzH7_CmgGZgBvH701x5vHiQdsoCZQMANrXlQlsE1oB-E08mIY-D6CgaFuEiFnGvqhE8PIRU697yOYRYE3jSM_jCIIA4igb4MNmAVxOHWQ63pBHIcRRIqsLyrJF5Uqkj9Zt801A6hYzgsOZqCseJkTsLO7QMuHh3zijgINAjiNkRMGPgwcFyJDXgT9aRxDFMI49mAUuhpn6E8jBH0YxWHoxqHB6bhT5CIHxcgJQhh4LdBLnBOWYW79ZP1KWEU6ONecEDaAmUqIJ844TD-Ywsj3IHTjCCFHw4TTKPBCHzpxHEfQ8cIaZRzBKQwCFDge9KJAYd-AmR-7U9-LFevIdepCYFAuCd52KVzl1ZBAhtbeBI2ftIu8qR87XhDFLooi1JQYzw2mse_CAAVQkeNocA6cIhQEbugjLw4DVIOLHHfqemEQ-7HnxChw9meNU2L9k5B7wrIORqxuJ2D32QYbmmWEgdnvn22wxazC-TVl9zpU73hRZ2_dVsGsLVb1OmAGmr_ugErE4jlNmoHd7vPuTw"
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
