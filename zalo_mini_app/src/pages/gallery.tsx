import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Page } from "zmp-ui";
import { api, photoSrc } from "../api";
import Icon from "../components/Icon";
import PhotoViewer from "../components/PhotoViewer";
import Sheet from "../components/Sheet";
import Skeleton, { EmptyState } from "../components/Skeleton";
import StoreSelect from "../components/StoreSelect";
import SubHero from "../components/SubHero";
import { MediaItem } from "../types";
import { dmy } from "../utils";

const KINDS: [string, string][] = [["all", "Tất cả"], ["task", "Công việc"], ["fund", "Quỹ"], ["order", "Nhận hàng"], ["announcement", "Bảng tin"]];
const KIND_LABEL: Record<string, string> = { task: "Công việc", fund: "Quỹ", order: "Nhận hàng", announcement: "Bảng tin" };

export default function GalleryPage() {
  const nav = useNavigate();
  const [kind, setKind] = useState("all");
  const [store, setStore] = useState("");
  const [items, setItems] = useState<MediaItem[] | null>(null);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState("");
  const [sel, setSel] = useState<MediaItem | null>(null);
  const [zoom, setZoom] = useState<string | null>(null);

  useEffect(() => {
    setItems(null);
    setError("");
    api.media({ kind, ...(store ? { storeCode: store } : {}) }).then((r) => { setItems(r.items); setTotal(r.total); })
      .catch((e) => setError(e instanceof Error ? e.message : "Không tải được kho ảnh"));
  }, [kind, store]);

  return (
    <Page className="page">
      <SubHero title="Kho ảnh" chip={items ? `${total} ảnh` : undefined} />
      <div className="chip-scroll">
        {KINDS.map(([k, v]) => <button key={k} className={`chip ${kind === k ? "active" : ""}`} onClick={() => setKind(k)}>{v}</button>)}
      </div>
      <div className="page-pad"><StoreSelect value={store} onChange={setStore} allowAll /></div>
      {error && <div className="error">{error}</div>}
      {!items && !error && <Skeleton count={2} />}
      {items && items.length === 0 && <EmptyState icon={<Icon name="image" size={34} />} title="Chưa có ảnh nào" hint="Ảnh từ công việc, báo cáo quỹ, nhận hàng và bảng tin sẽ gom về đây" />}
      <div className="gallery">
        {(items || []).map((m, i) => (
          <button key={`${m.name}-${i}`} className="gal-item" onClick={() => setSel(m)}>
            <img src={photoSrc(m.name, 240)} alt={m.title} loading="lazy" />
            <span>{KIND_LABEL[m.kind]}</span>
          </button>
        ))}
      </div>

      <Sheet open={!!sel} title={sel?.title || "Ảnh"} onClose={() => setSel(null)}>
        {sel && (
          <>
            <button className="gal-big" onClick={() => setZoom(sel.name)}><img src={photoSrc(sel.name, 800)} alt={sel.title} /></button>
            <div className="hint">{KIND_LABEL[sel.kind]}{sel.storeCode ? ` · ${sel.storeCode}` : ""}{sel.date ? ` · ${dmy(sel.date)}` : ""}</div>
            <div className="sheet-actions"><button className="btn primary" onClick={() => { const l = sel.link; setSel(null); nav(l); }}>Mở mục gốc</button></div>
          </>
        )}
      </Sheet>
      <PhotoViewer name={zoom} onClose={() => setZoom(null)} />
    </Page>
  );
}
