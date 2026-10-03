import React, { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Page, useSnackbar } from "zmp-ui";
import { absoluteUrl, api } from "../api";
import Icon from "../components/Icon";
import { PhotoStrip } from "../components/PhotoField";
import PhotoField from "../components/PhotoField";
import Sheet, { ConfirmSheet } from "../components/Sheet";
import Skeleton, { EmptyState } from "../components/Skeleton";
import StoreSelect, { useStoreChoice } from "../components/StoreSelect";
import SwipeRow from "../components/SwipeRow";
import SubHero from "../components/SubHero";
import { bumpData, useDataVersion, useOpsSummary } from "../data";
import { FUND_STATUS_LABEL, FundEntry, FundReport } from "../types";
import { digits, dmy, todayYmd, vnd } from "../utils";

export function DiffTag({ diff }: { diff: number }) {
  const d = Math.round(diff);
  if (d === 0) return <span className="tag-soft ok">Khớp</span>;
  return <span className={`tag-soft ${d > 0 ? "warn" : "bad"}`}>{d > 0 ? "Thừa" : "Thiếu"} {vnd(Math.abs(d))}</span>;
}

export default function FundPage() {
  const nav = useNavigate();
  const { openSnackbar } = useSnackbar();
  const version = useDataVersion();
  const ops = useOpsSummary();
  const [store, setStore] = useStoreChoice();
  const [reports, setReports] = useState<FundReport[] | null>(null);
  const [canManage, setCanManage] = useState(false);
  const [missing, setMissing] = useState<{ storeCode: string; storeName: string }[]>([]);
  const [entries, setEntries] = useState<FundEntry[]>([]);
  const [error, setError] = useState("");
  const [status, setStatus] = useState("");
  const [sheet, setSheet] = useState<null | "in" | "out">(null);
  const [amount, setAmount] = useState("");
  const [reason, setReason] = useState("");
  const [photos, setPhotos] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [delId, setDelId] = useState<number | null>(null);
  const [editEntry, setEditEntry] = useState<FundEntry | null>(null);
  const [delReport, setDelReport] = useState<FundReport | null>(null);
  const today = todayYmd();

  const load = useCallback(async () => {
    setError("");
    try {
      const res = await api.fundReports(status ? { status } : {});
      setReports(res.reports);
      setCanManage(res.canManage);
      if (res.canManage) api.fundMissing(today).then((m) => setMissing(m.stores)).catch(() => {});
    } catch (e) {
      setError(e instanceof Error ? e.message : "Không tải được dữ liệu");
    }
  }, [status, today]);

  const loadEntries = useCallback(() => {
    if (store) api.fundEntries(store, today).then((r) => setEntries(r.entries)).catch(() => {});
  }, [store, today]);

  useEffect(() => { load(); }, [load, version]);
  useEffect(() => { loadEntries(); }, [loadEntries, version]);

  const closeSheet = () => { setSheet(null); setEditEntry(null); setAmount(""); setReason(""); setPhotos([]); };
  const startEdit = (e: FundEntry) => {
    setEditEntry(e);
    setSheet(e.kind);
    setAmount(String(Math.round(e.amount)));
    setReason(e.reason);
    setPhotos(e.photoUrls);
  };
  const removeReport = async () => {
    if (!delReport) return;
    try {
      await api.deleteFundReport(delReport.id);
      openSnackbar({ text: "Đã xoá báo cáo quỹ", type: "success" });
      bumpData();
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không xoá được", type: "error" });
    }
    setDelReport(null);
  };
  const saveEntry = async () => {
    if (!sheet) return;
    setBusy(true);
    try {
      const body = { storeCode: store, kind: sheet, amount: Number(amount), reason: reason.trim(), photoUrls: photos };
      if (editEntry) await api.updateFundEntry(editEntry.id, body);
      else await api.addFundEntry(body);
      openSnackbar({ text: editEntry ? "Đã cập nhật khoản thu/chi" : sheet === "in" ? "Đã ghi khoản thu" : "Đã ghi khoản chi", type: "success" });
      closeSheet();
      bumpData();
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không lưu được", type: "error" });
    } finally {
      setBusy(false);
    }
  };

  const removeEntry = async () => {
    if (delId == null) return;
    try {
      await api.deleteFundEntry(delId);
      bumpData();
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không xoá được", type: "error" });
    }
    setDelId(null);
  };

  const exportCsv = async () => {
    try {
      const { path } = await api.exportLink("fund", store);
      window.open(absoluteUrl(path), "_blank");
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không tạo được liên kết tải", type: "error" });
    }
  };

  const mine = (ops?.storeCode || "").toUpperCase();
  const todays = (reports || []).find((r) => r.reportDate === today && r.storeCode.toUpperCase() === store.toUpperCase());
  const sumIn = entries.filter((e) => e.kind === "in").reduce((s, e) => s + e.amount, 0);
  const sumOut = entries.filter((e) => e.kind === "out").reduce((s, e) => s + e.amount, 0);

  return (
    <Page className="page">
      <SubHero
        title="Quỹ cuối ngày"
        note={canManage ? "Theo dõi báo cáo quỹ các cửa hàng" : "Báo cáo quỹ và thu/chi của cửa hàng"}
        right={<>
          {canManage && <button className="hero-btn" onClick={exportCsv} aria-label="Xuất Excel (CSV)"><Icon name="download" size={20} /></button>}
          <button className="hero-btn" onClick={() => nav(`/fund/new?store=${store || mine}`)} aria-label="Báo cáo quỹ mới"><Icon name="plus" size={22} /></button>
        </>}
      />

      <div className="page-pad"><StoreSelect value={store} onChange={setStore} /></div>

      {canManage && missing.length > 0 && (
        <section className="panel warn-panel">
          <div className="panel-head"><h3>Chưa báo cáo hôm nay</h3><span className="count">{missing.length} cửa hàng</span></div>
          <div className="chip-row nomargin">
            {missing.map((m) => <span key={m.storeCode} className="chip static">{m.storeName || m.storeCode}</span>)}
          </div>
        </section>
      )}

      <section className="panel">
        <div className="panel-head">
          <h3>Hôm nay · {dmy(today)}</h3>
          {todays && <span className={`badge fund-${todays.status}`}>{FUND_STATUS_LABEL[todays.status]}</span>}
        </div>
        {todays ? (
          <button className="today-report" onClick={() => nav(`/fund/${todays.id}`)}>
            <span><small>Tiền đếm được</small><b>{vnd(todays.cashTotal)}</b></span>
            <DiffTag diff={todays.difference} />
            <Icon name="chevron" size={16} className="chev" />
          </button>
        ) : (
          <button className="btn primary wide" onClick={() => nav(`/fund/new?store=${store}`)}>
            <Icon name="wallet" size={18} /> Báo cáo quỹ hôm nay
          </button>
        )}
        <div className="entry-head">
          <b>Thu / chi trong ngày</b>
          <span className="entry-sum"><i className="in">+{vnd(sumIn)}</i><i className="out">−{vnd(sumOut)}</i></span>
        </div>
        {entries.length === 0 && <div className="hint">Chưa có khoản thu/chi nào. Ghi lại khi nhập thêm hoặc chi tiền từ quỹ.</div>}
        {entries.map((e) => (
          <SwipeRow key={e.id} inPanel onEdit={e.canEdit ? () => startEdit(e) : undefined} onDelete={e.canDelete ? () => setDelId(e.id) : undefined}>
          <div className="entry">
            <span className={`entry-ico ${e.kind}`}><Icon name={e.kind === "in" ? "plus" : "minus"} size={16} /></span>
            <span className="entry-main"><b>{e.reason}</b><small>{e.createdByName}</small>{e.photoUrls.length > 0 && <PhotoStrip photos={e.photoUrls} />}</span>
            <span className={`entry-amt ${e.kind}`}>{e.kind === "in" ? "+" : "−"}{vnd(e.amount)}</span>
          </div>
          </SwipeRow>
        ))}
        <div className="sheet-actions entry-actions">
          <button className="btn" onClick={() => setSheet("in")}><Icon name="plus" size={16} /> Ghi thu</button>
          <button className="btn" onClick={() => setSheet("out")}><Icon name="minus" size={16} /> Ghi chi</button>
        </div>
      </section>

      <div className="chip-scroll">
        {[["", "Tất cả"], ["submitted", "Chờ duyệt"], ["rejected", "Cần đếm lại"], ["approved", "Đã duyệt"]].map(([k, v]) => (
          <button key={k} className={`chip ${status === k ? "active" : ""}`} onClick={() => setStatus(k)}>{v}</button>
        ))}
      </div>

      {error && <div className="error">{error} <button className="link" onClick={load}>Thử lại</button></div>}
      {!reports && !error && <Skeleton count={3} />}
      {reports && reports.length === 0 && <EmptyState icon={<Icon name="wallet" size={34} />} title="Chưa có báo cáo quỹ" hint="Bấm + để tạo báo cáo cuối ngày" />}
      <div className="list">
        {(reports || []).map((r) => (
          <SwipeRow key={r.id}
            onEdit={r.canEdit ? () => nav(`/fund/new?store=${r.storeCode}&date=${r.reportDate}`) : undefined}
            onDelete={r.canDelete ? () => setDelReport(r) : undefined}>
          <button className="card fund-card" onClick={() => nav(`/fund/${r.id}`)}>
            <div className="card-top">
              <span className="card-title">{dmy(r.reportDate)}{canManage ? ` · ${r.storeName}` : ""}</span>
              <span className={`badge fund-${r.status}`}>{FUND_STATUS_LABEL[r.status]}</span>
            </div>
            <div className="meta">
              <span className="meta-item"><Icon name="wallet" size={14} /> {vnd(r.cashTotal)}</span>
              <DiffTag diff={r.difference} />
              {canManage && <span className="meta-item"><Icon name="user" size={14} /> {r.submittedByName}</span>}
            </div>
          </button>
          </SwipeRow>
        ))}
      </div>

      <Sheet open={!!sheet} title={editEntry ? "Sửa khoản thu/chi" : sheet === "in" ? "Ghi khoản thu" : "Ghi khoản chi"} onClose={closeSheet}>
        <label className="field"><span>Số tiền (đ) *</span>
          <input inputMode="numeric" value={amount ? Number(amount).toLocaleString("vi-VN") : ""} onChange={(e) => setAmount(digits(e.target.value))} placeholder="VD: 150.000" />
        </label>
        <label className="field"><span>Lý do *</span>
          <input value={reason} onChange={(e) => setReason(e.target.value)} placeholder={sheet === "in" ? "VD: Khách trả nợ" : "VD: Mua túi, tiền ship"} maxLength={200} />
        </label>
        <div className="field"><span>Ảnh hoá đơn (nếu có)</span><PhotoField value={photos} onChange={setPhotos} max={3} /></div>
        <div className="sheet-actions">
          <button className="btn" onClick={closeSheet}>Huỷ</button>
          <button className="btn primary" disabled={busy || !Number(amount) || !reason.trim()} onClick={saveEntry}>{busy ? "Đang lưu..." : "Lưu"}</button>
        </div>
      </Sheet>

      <ConfirmSheet open={!!delReport} title="Xoá báo cáo quỹ?" message={delReport?.status === "approved" ? "Báo cáo này đã được duyệt. Xoá rồi sẽ không khôi phục được." : "Báo cáo sẽ bị xoá và không khôi phục được. Các khoản thu/chi trong ngày vẫn được giữ."} confirmLabel="Xoá" danger onConfirm={removeReport} onClose={() => setDelReport(null)} />
      <ConfirmSheet open={delId != null} title="Xoá khoản này?" message="Khoản thu/chi sẽ bị xoá khỏi quỹ hôm nay." confirmLabel="Xoá" danger onConfirm={removeEntry} onClose={() => setDelId(null)} />
    </Page>
  );
}
