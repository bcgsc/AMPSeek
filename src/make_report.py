# make_report.py
from pathlib import Path
from datetime import datetime
import base64
import sys

from jinja2 import Environment, FileSystemLoader

from report_utils import (
    Config,
    load_AMPlify_results,
    load_tAMPer_results,
    build_summary_table,
    plot_probability_scatter_individual,
    plot_attention_heatmap_single,
    load_pdb_map,
    class_breakdown_svg
)

def generate_images(summary_df, amp_df):
    """
    Return {Sequence_ID: {scatter_png, scatter_svg,
                          attention_png, attention_svg}}
    """
    images = {}
    scatter_map = plot_probability_scatter_individual(summary_df)

    for sid, plots in scatter_map.items():
        attn_row = amp_df.loc[amp_df["Sequence_ID"] == sid]

        if not attn_row.empty and "Attention" in attn_row.columns:
            attn_plots = plot_attention_heatmap_single(
                sequence_id=sid,
                sequence=attn_row["Sequence"].values[0],
                attention_str=attn_row["Attention"].values[0]
            )
        else:
            attn_plots = {"png": None, "svg": None}

        images[sid] = {
            "scatter_png":   plots["png"],
            "scatter_svg":   plots["svg"],
            "attention_png": attn_plots["png"],
            "attention_svg": attn_plots["svg"]
        }

    return images

def generate_report(amplify_tsv, tamper_csv, pdb_dir, results_dir, logo_png, template_path):
    cfg      = Config(amplify_tsv, tamper_csv, pdb_dir, results_dir, logo_png, template_path )
    amp_df   = load_AMPlify_results(cfg.AMPlify_TSV)
    tam_df   = load_tAMPer_results(cfg.tAMPer_CSV)
    summary  = build_summary_table(amp_df, tam_df)
    images   = generate_images(summary, amp_df)
    pdb_map  = load_pdb_map(summary, cfg.PDB_DIR)
    overview_svg = class_breakdown_svg(summary)

    records = summary.to_dict(orient="records")
    for r in records:
        r["image_data"] = images[r["Sequence_ID"]]
        r["pdb_b64"]    = pdb_map.get(r["Sequence_ID"])

    # embed logo
    with open(cfg.LOGO_PNG, "rb") as f:
        logo_data = base64.b64encode(f.read()).decode("ascii")

    # -- meta data (only date needed now) ------------------
    report_date = datetime.now().strftime("%Y/%b/%d")   # e.g. 2025/May/20

    # -- render HTML ---------------------------------------
    env = Environment(loader=FileSystemLoader("."), autoescape=True)
    tpl = env.get_template(cfg.TEMPLATE_PATH)

    html = tpl.render(
        title        = "",
        records      = records,
        logo_data    = logo_data,
        overview_svg = overview_svg,
        report_date  = report_date
    )

    cfg.Report_HTML.parent.mkdir(parents=True, exist_ok=True)
    cfg.Report_HTML.write_text(html, encoding="utf-8")
    print("Report written to", cfg.Report_HTML)

# ----------------------------------------------------------
if __name__ == "__main__":
    args = sys.argv[1:]
    generate_report(args[0], args[1], args[2], args[3], args[4], args[5])


