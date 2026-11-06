#!/usr/bin/env python3
import sys
from pathlib import Path

DEST = Path(sys.argv[1] if len(sys.argv) > 1 else "dbt/target/erd.html")

# Embed URL generated from sqltoerdiagram.com (no account needed)
# Diagram state is encoded in the fragment (#s=...) of the URL
SQLTOERDIAGRAM_EMBED_URL = (
    "https://sqltoerdiagram.com/?embed=1#s=z7Vltb9s2EP4rAj8lgLxafo29T1mrDt3SrHMdYMUyCLR0sblSlEZSabPC"
    "_30gKdGULFt20GIYsG-x7kjePXf33JH5gnCeozlKVglZY-SjR-CCZAzNAx-Jvyiao17PW8ADcGAxeBKvKAjvgmXe65_F5T17uQivl6G3vP7hJvTirGCSE6VwzzyPJN6b22X4Y7jw3i3evL1efPB-Dj_4SmQ0n6I4S8Bbhr8tvdtflt7t3c2Nd3f75te70NWqK9yzy-_vWfPkDU5zkjGxIXkknoSEtNMGhlNztv7FrY_2U8LJI_BoBUJGHERBpVCbaZkEnLZLylUCsMhYJHJKZH3VYUmeESZFlOvlQsXByoGSNVkRSqSBoxWFcv3X8j_HXBJMm57lmSCSZKw0tyl-wEIqXCjOm961r9PCtlVigzkkkd7XfiQiSrJiRcHZpgKj1_NekRSYRs6kajNPCI8LIk_HxqbdIZBoFmMblb2sPZDsi_B1uAhvX4bvdzVz4apdmr2xJLJIwFuE18YAmrF14xOmpVKF0CfykeSQEHw4UVZYQKRwPx2I1n1MyDs3aYENr1YcHglWCbH7-pBxqKelKHj9w7PBTLCEKHuIVoTLjffqemk4JgeeYgZMRjHmESvSFfBzoDwPxc50erZ7NqSRscNdZ2UXJDHaOScp1utpxnenn-CvYa9Oj58AaxjbeX2frVusbtGy9p9gKM8KlnTaWZJxebo11jHDaNiTSwZps9dIrGYjlziOoZlf9dRWGbpLTCKiGLMYKAVz1Kvw9fXdzdLrnx4q00M6y1MhdQwCrWD9kk95WzI3XJMkBSFxmnvLN2_D98vrt-_s978z5pZ4vIGkoJAo8t-1BU3vh7Oj1uusbR2gbbCIlAFRgiWuy50e8lPBYsVLLzgoBjYZ2N5PdMGdyIJnp5pbzW3qtYouu-8RdaNhF_CMOkEw1XlhbfSr0_3dzpdHCOGbgXC2XxU1thSopc8OX07i9G8bzhO9OKFH6-IFPZF8bSLYJX-XX6Xazr1ar3Vq773hrB6FR6Ce5JgJrIsR0_YKLEkuOs3DSvto1LSKUycKFL19JzRay65cc6Nf0pmZfuv8JpzRDuciirM0pyANeZmRaDcYRxyzjzWCdXoHSEyoQ6oSy0LsfitipFgI8kBamZGIyFwxKEQPGXeG632KrOGvBvZTUe8EsaZ4qJHuIVlHAj8Cx2uIRA6Q1AAwxzduGvs4JGAj0OF7TmQkZPbNAVCx3ycCivNDECUFb0zW-poSOU3ZoYtez3vpzFovhMQsIWwt2iuurHh3PPv6ZLk3Pz63yTmMdpDIOmvzE2GR5t22mYKsNyqfHggjYuPeU6uCqi0KTJImfxZCpuraYcepNoI6wkuVZnPM1B7vc-v-2PJvBPCsHvh_8LrfunaJ1BlCR7XxZLOfbI0yatZDPRtOG3laouwSUMY56EYvXuAiIfIo9zDNbvrdJYp3Kw0EZ5OE9SYSEnN5aobvlgHrAuLIe-eJ93snmhfWQ79pe_tYq8NwFLOz6vI_gVf9au2iZy82h7Dr9bx3wDCVT6oVrglb23dvkaWgXr69gsXAJSbM-0TkJiukl2YcvDhjEj6rreqDgtmus0QBcwbJ-QOCAP74nHV7jY-SGJhw31arZqavzdU5LMpJWy-0k5iCEvkoIZhCLNFc_S-BSEA-qo4UaP4F2QCqH5_RPBiOJj56QvPRcOujlgegSm96NdB6Qf9qq_Z03gJKlcl0qDVm04nayrzNlLJeEIy0cDgZbX1kn8eq3a-GY2PFONj6yFSblQ2mWjaZzLY-clYN-mOz6WjQ3_rIJJddFcxKe6eDrY90Z6tk_ZlZF_SH6rgyUqV0WDo6GalNnatUtXo062uFwUwhUbuMW5UrA-p4pKBw7riVQjAy1o21AbubjJUPgvIM5XMtlUqV6choaCspzivrpwasYaDDVI7LpXBkDA_6UwtybSaptp6YQI4HFeBtWsHgyuA0VBE90CKtP4FRns6U8vGeYkEsU-ZKg3iMUe2KsTkl6F-NlfeGAywyxqvJZKvsxSlwXImGBpjhxEcixhTQvP_deDZQm2DGMmnepND89z98tCFJAsz8nWJWYHpD2Ect3P4D"
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
