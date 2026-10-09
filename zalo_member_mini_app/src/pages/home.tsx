import React, { useEffect, useState } from "react";
import { followOA } from "zmp-sdk/apis";
import { useSnackbar } from "zmp-ui";
import { api, PublicStore } from "../api";
import BottomNav, { TabKey } from "../components/BottomNav";
import OverviewTab from "./overview";
import StoresTab from "./stores";
import AboutTab from "./about";

export default function HomePage() {
  const { openSnackbar } = useSnackbar();
  const [tab, setTab] = useState<TabKey>("home");
  const [stores, setStores] = useState<PublicStore[] | null>(null);
  const [error, setError] = useState("");
  const [oaId, setOaId] = useState("");

  const load = () => {
    setError("");
    api.stores().then(setStores).catch((e: Error) => setError(e.message || "Không tải được danh sách cửa hàng"));
  };

  useEffect(() => {
    load();
    api.oaInfo().then((r) => setOaId(r.oaId)).catch(() => {});
  }, []);

  const follow = async () => {
    try {
      await followOA({ id: oaId });
      openSnackbar({ text: "Đã theo dõi OA Bi'S MART. Bạn sẽ nhận ưu đãi và thông báo trên Zalo.", type: "success" });
    } catch (e) {
      const code = (e as { code?: number })?.code;
      openSnackbar({ text: code === -201 ? "Bạn đã từ chối theo dõi OA" : "Không mở được trang theo dõi OA (chỉ chạy trong Zalo)", type: "error" });
    }
  };

  return (
    <div className="member">
      <main className="m-main">
        {tab === "home" && <OverviewTab storeCount={stores?.length ?? null} canFollow={!!oaId} onFollow={follow} onGo={setTab} />}
        {tab === "stores" && <StoresTab stores={stores} error={error} onRetry={load} />}
        {tab === "about" && <AboutTab canFollow={!!oaId} onFollow={follow} />}
      </main>
      <BottomNav active={tab} onChange={setTab} />
    </div>
  );
}
