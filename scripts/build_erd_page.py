#!/usr/bin/env python3
import sys
from pathlib import Path

DEST = Path(sys.argv[1] if len(sys.argv) > 1 else "dbt/target/erd.html")

# Embed URL generated from sqltoerdiagram.com (no account needed)
# Diagram state is encoded in the fragment (#s=...) of the URL
SQLTOERDIAGRAM_EMBED_URL = (
    "https://sqltoerdiagram.com/?embed=1#s=z7Vltb9s4Ev4rAj8sWkB2Rb3T9ymXuofcptme4-7dYlsItMTYvMiUlqSS5gr_9wVJSZZkOXaKFocD7lusGZIzz8w8M2S-AlyWYAayVUbXGNjggXBBCwZm0AbijxzMwGRiLcgd4YSlxJJ4lRNhvWKF9e5n8foTu1zML5Zza3nx1-u5lRYVk5wqhU_MsmhmXd0s53-bL6wPi6v3F4vfrJ_nv9lKZDSfkrTIiLWc_2tp3fyytG4-Xl93xSOSy19ubpeLi6ubpVX9kbQHJr0NP95c_ePj3HrV_fj6E3v9l09saPEGb0taMLGhZSKehCTbk7YzvDU261-8xab9lHH6QHiyIkImnIgql0JtpmWS4O24pF4lCBYFS0SZU9lfdVxSFpRJkZR6uVDxa-Ukp2u6ojmVBs1RFOr138v_EnNJcT70rCwElbRgtblD8R0WUuGS43Lo3fg6LRxbJTaYkyzR-7YfqUiyolrlpLNNA8ZkYr2lW8I0cibFh3lCeVpReT42_awdASkvUtxG5SDpjxTJYv5uvpjfXM5v97XWz3KzN5ZUVhmxFvMLY0BesPXgE85rpQahR3pPS5JRfDxRVliQROF-PhCj-5iQn9xkBDa8WnHyQLFKiP3Xu4KTflqKivc_fDOYGZYkKe6SFeVyY729WM5NkhO-xYwwmaSYJ6zargh_CZQvQ_FkOn2ze21IE2NHd10re0Uzo11yusV6fV7w_eln-GvY66THTwRrGAf94JCmR8wd0WoN71s40kpqdtXnN_1D_RjvG7yoWHbSmXrP2tLGo67JRqO1sqaZMd-MpNUcJBzHKRkmYT__VRrvs5eKJMUsJXlOzFFv5-8uPl4vLef8eJpGc7KGFVLPQaAVWr_kUzmW8QPXJN0SIfG2tJZX7-e3y4v3H9rv_ylYlwfSDcmqnGSqQ-x7h-4BxzOp1xBb206AtsEiUQYkGZa4L-80mr9XLFXk9YYTRdMmW8ebjq7KM6nyxanWLfkx9V7Z1y36GXWj0S7gRU6OVVrXrabSWvPtxjB7f-h4CdZLfhQ-L3a5odaR2m3p94QvZ_WEHxvpM704o8fruiZ6ovneHLFPoFN-1Wp793q9ulOWt4bOJjl5ILklOWYC6zrF-Xhx1vyXnOdho_1s1LRKp4QUKHr7k9BorXblmhv9munM9NynPtEZDXGprk_bMifS8JoZqfaDdcIxu-9xb6etEIlp3uFbiWUl9r8VZ-ZYCHpHR0mTisRcUXKS3BW8M5wfsmcPfzXwn4v6SRB7isd67AGSfSTwA-F4TRJREpL1ADDHD24qhzhkpI3ACd9LKhMhix8OgIr9IRHkuDwGUVbxwWSurzlJp1936GIysS47I9sbITHLKFuL8YqrK7475X1_shyfP7-h_3UY7SiRnazNR8rMy8bYuEHXG5VPd5RRsenec5uC6i2CJkmzf1dCbtW1pZ20xgjqGV5qNIcTqPb4kFsPJ5r_RgBf1AP_H7zTb2X7RDoZwo7q4MnnMNkGZTSsh342nDfyjES5S0AF50Q3evEGVxmVz3IP0-ym322SdL_SQPBikmi9SYTEXJ6b4ftlhJ0C4vg767nvA53ZvbxPMpZ242u9ap22h-6MT7o6Ms_C-KJS_Z-AsH8R7wMqh4C2159jcE4m1gfCcC6fVMNcU7ZuX-VFsSXqXd6qWEq4xJRZj1Ruikpa24ITKy2YJF_UVv1xwmx3spAJ5oxkLx8jBOEP37LuoD3mNCVMdF9wm5an793NOSwp6VjHbOc1BSWwQUZxTlIJZuo_HVQSYIPmSAFmX0GNi_rzC5hNYhs8gdnEQ85OKXZeCBoN6HqBUfIjuLPByINURzUyqlGg9muf2moF6EJfy33fV8fVE18tdcPQLIauWpzjRuC5jhYgteig2zaHR47RmgRRvLPByGDVmunA2swgcHc2qAPViF3f1VKorOgFsXHDgTVq0c4G-7tKu0FQA-bBuFFoljYAeREaYrlvKbVyEHoGLdT6U0tiaEx0I2VB507YyANkXFDi52l-HxpzmArxc3zWYhAaEGDQrGh3qg_3XOW9qfjGI6_Ot1D7VL__1cIorIW-r8zuPB-0XtW4hkgnYsNOrUlxnQEu2p_cBwZCt9nDRzu1Cd4SjmtpGJno-LFvA5HinICZM_WRPg4zVkjzuAVmv38FNAMzgLeP_prjzePEBzZQ0yeYgTUvqhLYJtegE0_j2PEgClAYw8CgPAl9bxpBF6LAQ1HgoNgGj2AWxv40dqHrIBe5XgyRDTZgFkT-FMZRAMMYhpHnIIX3F1Xii0pR5E_WbXPJAAqWvOBgBsqKlzkBO7trKnPX_sQdN9Vz_WmAoB_GyHPj2HVMrU58L5yiwHNCN3Rc6CKoTY0COHWDKEYwdCCMolCbGkM0jZzQ94MoiuMo3luKU2L9k5B7wrKOkVhN1gMbU-ngCRy1MXCiaQT9IHLiEHm-W8dr4jlT5MYIxSj2owiF0MCJYmfqhKEbQt_x4zDyDJzImwY-8lwYuh70lJu1kUuCt10IV3k1BLB8eMgn3qhxPgqmAfLdEHmOEwTKBk2FvjN1Yw_GyPODIFYV8AhmcRRMY9cJnBhFkUoBbVoIvanrKZBdGCocW9MucU5Yhrn1k_UrYZWi9cbKNSeEgd1nG2xolhEGZr93mHecsA292m036JDxsA18tsEWswrn15Tdm9S_44WuSd2iwaytY20TmIHm34BAMUPxnCbNwG73efcn"
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
