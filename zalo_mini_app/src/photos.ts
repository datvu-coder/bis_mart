import { chooseImage } from "zmp-sdk/apis";

export type PhotoSource = "camera" | "album";

const CANCEL_RE = /cancel|huỷ|hủy|-201|user.*(denied|reject)/i;

/** Opens Zalo's native camera/album picker and returns the chosen photos as Files. */
export async function pickPhotos(source: PhotoSource, max = 3): Promise<File[]> {
  let paths: string[];
  try {
    const res = await chooseImage({ sourceType: [source], count: max });
    paths = res.filePaths || [];
  } catch (e) {
    const err = e as { message?: string; code?: number | string };
    const detail = `${err?.message ?? ""} ${err?.code ?? ""}`.trim();
    if (CANCEL_RE.test(detail)) return [];
    throw new Error(`Không mở được ${source === "camera" ? "camera" : "thư viện ảnh"}${detail ? ` (${detail})` : ""}`);
  }

  const files: File[] = [];
  for (const [i, path] of paths.entries()) {
    try {
      const blob = await (await fetch(path)).blob();
      files.push(new File([blob], `photo-${Date.now()}-${i}.jpg`, { type: blob.type || "image/jpeg" }));
    } catch {
      throw new Error("Không đọc được ảnh vừa chọn. Hãy thử chọn lại hoặc dùng bộ chọn dự phòng.");
    }
  }
  return files;
}

/** Downscales large phone photos before upload (faster on mobile data, stays under the 10MB limit). */
export async function compressImage(file: File, maxSide = 1600, quality = 0.82): Promise<File> {
  try {
    const url = URL.createObjectURL(file);
    const img = await new Promise<HTMLImageElement>((resolve, reject) => {
      const el = new Image();
      el.onload = () => resolve(el);
      el.onerror = reject;
      el.src = url;
    });
    URL.revokeObjectURL(url);
    const scale = Math.min(1, maxSide / Math.max(img.width, img.height));
    if (scale === 1 && file.size < 1.5 * 1024 * 1024) return file;
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(img.width * scale);
    canvas.height = Math.round(img.height * scale);
    canvas.getContext("2d")!.drawImage(img, 0, 0, canvas.width, canvas.height);
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/jpeg", quality));
    if (!blob || blob.size >= file.size) return file;
    return new File([blob], file.name.replace(/\.\w+$/, "") + ".jpg", { type: "image/jpeg" });
  } catch {
    return file;
  }
}
