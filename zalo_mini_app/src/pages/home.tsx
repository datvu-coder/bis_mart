import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Page } from "zmp-ui";
import BottomNav, { TabKey } from "../components/BottomNav";
import Icon from "../components/Icon";
import { uiState, useTaskData } from "../data";
import MeTab from "./tabs/me-tab";
import SummaryTab from "./tabs/summary-tab";
import TasksTab from "./tabs/tasks-tab";

const ORDER: TabKey[] = ["tasks", "summary", "me"];

/**
 * One shell for the three main tabs: the bottom bar stays put and only the panel content cross-fades,
 * instead of every tab being a separate animated route.
 */
export default function HomePage() {
  const nav = useNavigate();
  const data = useTaskData();
  const [tab, setTabState] = useState<TabKey>(uiState.tab);
  const [jump, setJump] = useState<{ store: string; nonce: number } | null>(null);

  const current: TabKey = tab === "summary" && !data.canManage ? "tasks" : tab;
  const setTab = (t: TabKey) => { uiState.tab = t; setTabState(t); };
  const activeIndex = ORDER.indexOf(current);

  const panel = (key: TabKey, children: React.ReactNode) => {
    const idx = ORDER.indexOf(key);
    const state = idx === activeIndex ? "active" : idx < activeIndex ? "left" : "right";
    return (
      <div className={`tab-panel ${state}`} aria-hidden={idx !== activeIndex}>
        {children}
      </div>
    );
  };

  return (
    <Page className="shell-page disable-scrolling">
      {panel("tasks", <TasksTab {...data} jump={jump} />)}
      {data.canManage && panel("summary", (
        <SummaryTab
          active={current === "summary"}
          onOpenStore={(store) => { setJump({ store, nonce: Date.now() }); setTab("tasks"); }}
        />
      ))}
      {panel("me", <MeTab tasks={data.tasks} />)}

      {data.canManage && current === "tasks" && (
        <button className="fab" onClick={() => nav("/new")}><Icon name="plus" size={20} /> Giao việc</button>
      )}
      <BottomNav tab={current} canManage={data.canManage} onChange={setTab} />
    </Page>
  );
}
