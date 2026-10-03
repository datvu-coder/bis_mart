import React, { useCallback, useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { Page, useSnackbar } from "zmp-ui";
import { api } from "../api";
import Icon from "../components/Icon";
import { PhotoStrip } from "../components/PhotoField";
import Sheet from "../components/Sheet";
import SubHero from "../components/SubHero";
import { bumpData } from "../data";
import { FUND_DENOMS, FUND_STATUS_LABEL, FundReportDetail } from "../types";
import { dmy, formatDateTime, vnd } from "../utils";
import { DiffTag } from "./fund";

export default function FundDetailPage() {
  const { id } = useParams();
  const nav = useNavigate();
  const { openSnackbar } = useSnackbar();
  const [r, setR] = useState<FundReportDetail | null>(null);
  const [error, setError] = useState("");
  const [rejecting, setRejecting] = useState(false);
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);

  const load = useCallback(() => {
    api.fundReport(Number(id)).then(setR).catch((e) => setError(e instanceof Error ? e.message : "Không tải được báo cáo"));
  }, [id]);
  useEffect(load, [load]);

  const review = async (decision: "approve" | "reject") => {
    setBusy(true);
    try {
      await api.reviewFundReport(Number(id), decision, note.trim());
      openSnackbar({ text: decision === "approve" ? "Đã duyệt báo cáo" : "Đã yêu cầu đếm lại", type: "success" });
      setRejecting(false);
      setNote("");
      bumpData();
      load();
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không xử lý được", type: "error" });
    } finally {
      setBusy(false);
    }
  };

  if (error) return <Page className="page"><SubHero title="Báo cáo quỹ" /><div className="error">{error}</div></Page>;
  if (!r) return <Page className="page"><SubHero title="Báo cáo quỹ" note="Đang tải..." /></Page>;

  const rows = FUND_DENOMS.filter((d) => r.counts[String(d)]);
  return (
    <Page className={`page ${r.canReview ? "with-bar" : ""}`}>
      <SubHero title={`${r.storeName} · ${dmy(r.reportDate)}`} note={`${r.submittedByName} gửi lúc ${formatDateTime(r.createdAt)}`}
        right={r.canEdit ? <button className="hero-btn" onClick={() => nav(`/fund/new?store=${r.storeCode}&date=${r.reportDate}`)} aria-label="Sửa"><Icon name="edit" size={20} /></button> : undefined} />

      <div className="stat-card three">
        <div className="stat static"><b className="sm">{vnd(r.cashTotal)}</b><span>Tiền đếm được</span></div>
        <div className="stat static"><b className="sm">{vnd(r.systemBalance)}</b><span>Theo hệ thống</span></div>
        <div className="stat static"><b className="sm"><DiffTag diff={r.difference} /></b><span>Chênh lệch</span></div>
      </div>

      <section className="panel">
        <div className="panel-head"><h3>Trạng thái</h3><span className={`badge fund-${r.status}`}>{FUND_STATUS_LABEL[r.status]}</span></div>
        {r.reviewedByName && <div className="hint">{r.reviewedByName} xử lý {r.reviewedAt ? formatDateTime(r.reviewedAt) : ""}</div>}
        {r.reviewNote && <p className="desc">Ghi chú quản lý: {r.reviewNote}</p>}
        {r.note && <p className="desc">Ghi chú: {r.note}</p>}
      </section>

      <section className="panel">
        <h3>Chi tiết kiểm đếm</h3>
        <div className="kv-list">
          {rows.length === 0 && <div className="hint">Không có mệnh giá nào</div>}
          {rows.map((d) => (
            <div key={d}><span>{d.toLocaleString("vi-VN")} đ × {r.counts[String(d)]}</span><b>{vnd(d * r.counts[String(d)])}</b></div>
          ))}
          {r.otherAmount > 0 && <div><span>Tiền khác</span><b>{vnd(r.otherAmount)}</b></div>}
        </div>
      </section>

      {r.entries.length > 0 && (
        <section className="panel">
          <h3>Thu / chi trong ngày</h3>
          {r.entries.map((e) => (
            <div key={e.id} className="entry">
              <span className={`entry-ico ${e.kind}`}><Icon name={e.kind === "in" ? "plus" : "minus"} size={16} /></span>
              <span className="entry-main"><b>{e.reason}</b><small>{e.createdByName}</small><PhotoStrip photos={e.photoUrls} /></span>
              <span className={`entry-amt ${e.kind}`}>{e.kind === "in" ? "+" : "−"}{vnd(e.amount)}</span>
            </div>
          ))}
        </section>
      )}

      {r.photoUrls.length > 0 && <section className="panel"><h3>Ảnh đính kèm</h3><PhotoStrip photos={r.photoUrls} /></section>}

      {r.canReview && (
        <div className="action-bar">
          <button className="btn" disabled={busy} onClick={() => setRejecting(true)}>Yêu cầu đếm lại</button>
          <button className="btn primary" disabled={busy} onClick={() => review("approve")}>Duyệt</button>
        </div>
      )}

      <Sheet open={rejecting} title="Yêu cầu đếm lại" onClose={() => setRejecting(false)}>
        <label className="field"><span>Lý do *</span><textarea value={note} onChange={(e) => setNote(e.target.value)} placeholder="VD: Chênh lệch lớn, đếm lại giúp anh/chị" /></label>
        <div className="sheet-actions">
          <button className="btn" onClick={() => setRejecting(false)}>Huỷ</button>
          <button className="btn danger-solid" disabled={busy || !note.trim()} onClick={() => review("reject")}>Gửi yêu cầu</button>
        </div>
      </Sheet>
    </Page>
  );
}
