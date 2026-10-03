import React, { useRef, useState } from "react";
import { useSnackbar } from "zmp-ui";
import { api, photoSrc } from "../api";
import { compressImage, pickPhotos, PhotoSource } from "../photos";
import Icon from "./Icon";
import PhotoViewer from "./PhotoViewer";
import Sheet from "./Sheet";

interface Props {
  value: string[];
  onChange: (next: string[]) => void;
  max?: number;
  label?: string;
}

/** Photo attachments for forms: camera/album/fallback picker, thumbnails, remove, full-screen preview. */
export default function PhotoField({ value, onChange, max = 6, label = "Thêm ảnh" }: Props) {
  const { openSnackbar } = useSnackbar();
  const fileRef = useRef<HTMLInputElement>(null);
  const [sheet, setSheet] = useState(false);
  const [busy, setBusy] = useState(false);
  const [viewer, setViewer] = useState<string | null>(null);

  const upload = async (files: File[]) => {
    if (!files.length) return;
    setBusy(true);
    const next = [...value];
    try {
      for (const f of files.slice(0, Math.max(0, max - next.length))) {
        const { photoUrl } = await api.uploadPhoto(await compressImage(f));
        next.push(photoUrl);
        onChange([...next]);
      }
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không tải được ảnh lên", type: "error" });
    } finally {
      setBusy(false);
    }
  };

  const add = async (source: PhotoSource) => {
    setSheet(false);
    try {
      await upload(await pickPhotos(source, Math.max(1, max - value.length)));
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không lấy được ảnh", type: "error" });
    }
  };

  const onFallback = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    e.target.value = "";
    await upload(files);
  };

  return (
    <>
      <div className="photos">
        {value.map((p) => (
          <div key={p} className="photo-wrap">
            <button type="button" className="photo" onClick={() => setViewer(p)}><img src={photoSrc(p, 240)} alt="Ảnh đính kèm" /></button>
            <button type="button" className="photo-x" onClick={() => onChange(value.filter((x) => x !== p))} aria-label="Xoá ảnh"><Icon name="close" size={12} /></button>
          </div>
        ))}
        {value.length < max && (
          <button type="button" className="photo-add" onClick={() => setSheet(true)} disabled={busy}>
            <Icon name="camera" size={22} /><span>{busy ? "Đang tải..." : label}</span>
          </button>
        )}
      </div>
      <input ref={fileRef} type="file" accept="image/*" multiple hidden onChange={onFallback} />
      <PhotoViewer name={viewer} onClose={() => setViewer(null)} />
      <Sheet open={sheet} title="Thêm ảnh" onClose={() => setSheet(false)}>
        <div className="menu">
          <button type="button" onClick={() => add("camera")}><Icon name="camera" size={20} /> Chụp ảnh mới</button>
          <button type="button" onClick={() => add("album")}><Icon name="inbox" size={20} /> Chọn từ thư viện</button>
          <button type="button" className="muted-row" onClick={() => { setSheet(false); fileRef.current?.click(); }}>Không được? Dùng bộ chọn dự phòng</button>
        </div>
      </Sheet>
    </>
  );
}

/** Read-only thumbnail strip with tap-to-enlarge. */
export function PhotoStrip({ photos }: { photos: string[] }) {
  const [viewer, setViewer] = useState<string | null>(null);
  if (!photos.length) return null;
  return (
    <>
      <div className="photos">
        {photos.map((p) => (
          <button key={p} type="button" className="photo" onClick={() => setViewer(p)}><img src={photoSrc(p, 240)} alt="Ảnh" loading="lazy" /></button>
        ))}
      </div>
      <PhotoViewer name={viewer} onClose={() => setViewer(null)} />
    </>
  );
}
