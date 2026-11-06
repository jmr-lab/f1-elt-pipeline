#!/usr/bin/env python3
import sys
from pathlib import Path

DEST = Path(sys.argv[1] if len(sys.argv) > 1 else "dbt/target/erd.html")

# Embed URL generated from sqltoerdiagram.com (no account needed)
# Diagram state is encoded in the fragment (#s=...) of the URL
SQLTOERDIAGRAM_EMBED_URL = (
    "https://sqltoerdiagram.com/#s=z7Vltb9s4Ev4rAj8cWkB2Jerd-ymXuofcptmu497tYlsItDSxeZEpLUklmy383xcUJVmS5dgpWhwOuI_WDMmZZ2aeGdJfECkKNEPpKqVrgkz0AFzQnKGZbSLxe4ZmaDIxFnAHHFgChiSrDITxiuXGux_F60_scjG_WM6N5cXfr-dGkpdMcqoUPjHDoKlxdbOc_2O-MD4srt5fLH41fpz_aiqR1nyKkzwFYzn_ZWnc_LQ0bj5eX3fFI5LLn25ul4uLq5ulUf4etwfGvQ0_3lz9_HFuvOp-fP2Jvf7hExtavCHbguZMbGgRiychYXvSdka22ubqF2-xaT-lnD4Aj1cgZMxBlJkUarNKJoFsxyX1KgFE5CwWRUZlf9VxSZFTJkVcVMuFil8rh4yu6YpmVGo0R1Go138r_wvCJSXZ0LMiF1TSnNXmDsV3REiFS0aKoXfj6yrh2CqxIRzSuNq3_UhFnOblKoPONg0Yk4nxlm6BVcjpFB_mCeVJSeX52PSzdgSkLE9IG5WDpD9SJIv5u_lifnM5v93XWj_L9d5EUlmmYCzmF9qALGfrwSeS1UoNQo_0nhaQUnI8UVZEQKxwPx-I0X10yE9uMgIbWa04PFCiEmL_9S7n0E9LUfL-h68GMyUS4vwuXlEuN8bbi-VcJznwLWHAZJwQHrNyuwL-EihfhuLJdPpq99qQxtqO7rpW9oqmWrvgdEuq9VnO96ef4a9mr5MePwGpYBz0g0OaHjF3RKs1vG_hSCup2bU6v-kf6sd43-B5ydKTztR71pY2HnVN1hqtlTXNjPmmJa3mIOE4SWCYhP38V2m8z14q4oSwBLIM9FFv5-8uPl4vDev8eOpGc7KGFVLPQVAptH7Jp2Is4weuSboFIcm2MJZX7-e3y4v3H9rvf-asywPJBtIyg1R1iH3vqHrA8UzqNcTWthOgbYiIlQFxSiTpyzuN5p8lSxR5veGgaFpn63jTqaryTKp8cap1S35MvVf2dYt-Rl1rtAt4nsGxSuu61VRaa77ZGGbuDx0vwXrJ98LnxS431DpSuy39nvDlrJ7wfSN9phdn9PiqrqGaaL41R-wT6JRftdrevV6v7pTlraazSQYPkBmSEyZIVackGy_Omv_i8zxstJ-NWqXSKSEFSrX9SWgqrXblmmv9mun09NynPtEZDUmhrk_bIgOpeU2PVPvBOuaE3fe4t9NWQBKadfhWElmK_W_FmRkRgt7RUdKkItZXlAziu5x3hvND9uzhrwb-c1E_CWJP8ViPPUCyjwR5AE7WEIsCIO0BoI8f3FQOcUihjcAJ3wsqYyHz7w6Aiv0hEWSkOAZRWvLBZF5dc-JOv-7QxWRiXHZGtjdCEpZSthbjFVdXfHfK-_ZkOT5_fkX_6zDaUSI7WZuPlOmXjbFxg643Kp_uKKNi073nNgXVW2TrJE3_Uwq5VdeWdtIaI6hneKnRHE6glceH3Ho40fw3AviiHvj_4J1-K9sn0skQdlQHTz6HyTYoo2E99LPhvJFnJMpdAso5h6rRizekTKl8lntYxW7Vu02c7FdqCF5MEq03sZCEy3MzfL8M2Ckgjr-znvs-0Jndi_s4ZUk3vsar1mlz6M74pFtF5lkYX1Sq_xMQ9i_ifUDlEND2-nMMzsnE-ACMZPJJNcw1Zev2VV7kW1Dv8kbJEuCSUGY8UrnJS2lscw5GkjMJf6it-uOE3u5kIQPhDNKXjxEC-MPXrDtojxlNgInuC27T8qp7d3MOiws61jHbeU1BiUyUUpJBItFM_dNBJSATNUcKNPuCeq8A6sMfaDbxA99ET2g2wXhnohq6VuiEldBxAyWsx7RGiqOokrqOtzNRRhqBF-jPtrUzUfvmVgtt18b6QNt3diYaeeRqNB29zyTw_J2J9heD9vzA0gqOa-9MVIPeSn1t3cTGTrO82blZF6qNe8FqVjcqgXJNp24tcsLaft9S_tUPWbXQtep1rlU511RRLfaDei329_vWd7pGJdSQT1wc7VU6APph7Zdf-TUyRTY-hL5dn-ap0w6GlTbKjbPYVng8R2n1krBG3lMWdGyLbJ1MOHL3pj2_le9oI529jQM8NGS2reQ9keN7-rRApe6Rdj4IjGvvlC7ZAieNM7ajRSpvRUIyQDNr6mt4CWO51O9aaPbbF0RTNENk--iuGV67E4xMpAZPNENrnpcFMitEHexOvch2_TBycBhiy61j6vjTyHMsH_sWtnFkm-gRzXxsTcMwcDH2QtfGjm-iDZoFQTD1cBD4ro99x1LIKrJDM7QgCRj_BrgHliKVZFnOK6tWwNHO7BqZSItM7FEjHRxMAzvAoe9ix4qsqK62aOo7kWd5ruX6Vug4uLIxxMEUe4HlRVboe07kVTZ6gTUNXdvHVoQDz_Gi1sYlkK3oGLfKShjYVjw8ZBNn3DbPm1puYFlYbYobivIDf-qFUejhMHTcQMXtEc08L5h6vmOHgec5ro01fL7lqa84CK0otDxVCrVplyQDlhJu_M34F7ASOlauOQAbmMnJ5nHijsc5jNypZwWhrY53vIbZHNebOoET2WHkuJYVWIE2FFtTHzuB7fmWHzoq-gpDz5s6totd2w8t1-_E-ba5P3YsLEpeZIB2n020oWkKDM1-q6h3z90dolYNoMv5XToep97PJtoSVpLsmrJ7nfJ3PK_qu-rKaNYyXmUUmqHmnz-k6jd_TpOmaLf7vPsL"
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
