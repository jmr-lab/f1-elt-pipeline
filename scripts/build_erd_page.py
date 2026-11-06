#!/usr/bin/env python3
import sys
from pathlib import Path

DEST = Path(sys.argv[1] if len(sys.argv) > 1 else "dbt/target/erd.html")

# Embed URL generated from sqltoerdiagram.com (no account needed)
# Diagram state is encoded in the fragment (#s=...) of the URL
SQLTOERDIAGRAM_EMBED_URL = (
    "https://sqltoerdiagram.com/?embed=1#s=z7Vlbb9s4Fv4rAh8WLSC7ou7yPmVTd5GdNNN13JkdTAuBlhibG5nSkFTSTOH_viAp0ZIsx07RYrHAPlrnkPzOd66kvwJUVWAG8lVO1gjY4AEzTkoKZtAG_I8CzMBkYi3wHWaYZtgSaFVgbr2ipfXuJ_76E71czC-Wc2t58bfruZWVNRWMSIVP1LJIbl3dLOd_ny-sD4ur9xeL36yf5r_ZUqQ1n9KszLG1nP9rad38vLRuPl5fd8Ujksufb26Xi4urm6VV_5GaA9Pehh9vrv75cW696n58_Ym-_usnOkS8QduKlJRvSJXyJy7w9iR2irYas_rFDDfmU87IA2bpCnORMszrQnC5mZIJjLbjkmYVx4iXNOVVQUR_1XFJVRIqeFqp5Vz6z8hxQdZkRQoiNJujLDTrv5f9FWKCoGJoWVVyIkhJG7hD8R3iQvJSoGpo3fg6JRxbxTeI4TxV-5qPhKd5Wa8K3NmmJWMysd6SLaaKOR3iwzghLKuJOJ-bftSOkFSUGTJeOQj6I0mymL-bL-Y3l_Pbfa71o1zvjQQRdY6txfxCAyhKuh58QkWj1DL0SO5JhXOCjgfKCnGcSt7PJ2J0H-3yk5uM0IZWK4YfCJIBsf96VzLcD0tes_6HbyYzRwKn5V26IkxsrLcXy7kOcsy2iGIq0gyxlNbbFWYvofJlLJ4Mp282z7g01Ti664zsFcm1dsXIFqn1Rcn2p59hr65eJy1-wkjROOgHh2V6BO6IlgHeRzjSSprqqs5v-4f8Md43WFnT_KQxzZ4N0taiLmStYVA2ZWbMNi0xmoOAYyjDwyDsx78M4330Ep5miGa4KLA-6u383cXH66XlnO9P3WhO5rBk6jkKlIKxSzxVYxE_ME2QLeYCbStrefV-fru8eP_BfP-zpN06kG1wXhc4lx1i3ztUDzgeSb2GaLCdIG2DeCoBpDkSqC_vNJp_1DSTxesNw7JM62gdbzoqK88slS8OtW7Kj6n30r5p0c-oaw2zgJUFPpZpXbPaTDPw7RaYvT90PAWbJT-Knxeb3JbWkdw15feELWf1hB_r6TOtOKPHq7zGaqL53jViH0Cn7GrU9ub1enUnLW91OZsU-AEXlmCIcqTyFBXjydnUv_Q8C1vtZ72mVDopJElR25-kRmmZlWum9ZtKp6fnfunjndEQVfL6tK0KLHRd0yPVfrBOGaL3vdrbaStYIFJ06q1Aoub737JmFohzckdGiybhqb6iFDi9K1lnOD-snj3-5cB_LusnSewpHuuxB0z2mUAPmKE1TnmFcd4jQB8_uKkc8pBj44ETtldEpFyUP5wA6fvDQlCg6hhFec0Gk7m65qSdft0pF5OJddkZ2d5wgWhO6JqPZ1yT8d0p7_sXy_H58xv6X6eiHS1kJ3PzkVD9sjE2bpD1RsbTHaGEb7r33DaheougDtL83zUXW3ltMZPWWIF6pi61msMJVFl8WFsPJ5r_hgNf1AP_77zTb2X7QDrpwo7q4MnnMNgGaTTMh340nDfyjHi5W4BKxrBq9PwNqnMinq09VFU39W6TZvuVmoIXFwljTcoFYuLcCN8vw_QUEcffWc99H-jM7tV9mtOs61_rlTHaHpozPukqzzxL44tS9X-Cwv5FvE-oGBJqrj_H6JxMrA-YokI8yYa5JnRtXuV5ucXyXd6qaYaZQIRaj0RsylpY25JhKyupwF_kVv1xQm93MpExYhTnLx8jOGYP37LuoD0WJMOUd19w25an7t3tOTStyFjHNPOapBLYICeowJkAM_lPBxEY2KA9koPZV3DQreTHL2A2iRzHBk9gNgmieGeDkcGk1YQOjBrVwN3ZoDG0Fbu-q6TQ2cs0CY0GdKBe7kU7G-xnfbNBEDRyGLcK7VKvOdmLkp0NjlTvRjkIPaXsS1Udea3Ei_U2oZI171CNMAoboe9LfJ1rbKMQt_jCBMrVbZYY8-KGSTeR-Ht3-lYHukEXQe9tpuUhjMJmH8lyE9BG2JjgKZDt8GwoTBJtuhfsbFCgVhBo-nzlm-frv0EaaGu8yN_ZKnxaiRs1NkgLnquBhhhXY4aOZ45vSQ900LiRBGzeaNuVPtTiCQzl0pFH0WGAREHYouodFHuaVBjt5EZoixlqRKHbsJN4NuAZKjCYOVNfpQOitBT6aQvMfv8KSA5mAG0f_TV11_7EBTaQsyeYgTUr6wrYyg2e60-DBPphnHhuHLuO30SWF06TwHNCN3Rc6CbQBo-SAzh1gyhOYOhAGEnvb8Ashsk0ckLfD6IojqNYGvVF5vcCZdj6FeN7THMgw7AomQK1wgzs7C7GTDhoAkcxBk40jaAfRE4cJp7vRm2COdPEjZMkTmI_ipIQxgpjEjtTJwzdEPqOH4eRpzAGiTcN_MRzYeh60JNmNiCXGG15B92qqPEAXPXwUEy8UXB-EkyDxHfDxHOcIJAYlG99Z-rGHowTzw-CWGbCI5jFUTCNXSdw4iSKvEQG5wbMQuhNXU-S7MJQ8migXaIC0xwx6y_WL5jWuINyzTCmA5gMbR4n_rifIXTiaRw7HkyCJIxhoAvPJPS9aQRdmAQSj5NooGHsT2MXuk7iJq4Xw0RzGPlTGEcBDGMYRp6TGKC37RWyg7CqWVVgsPtsgw3Jc0zB7HeV5_tC0akKwwLTzbDxbPpsgy2iNSquCb3XIX_HSpVlqjGDmamaChSYgfbPPyDzrnxOk-Rgt_u8-w8"
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
