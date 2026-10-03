import React, { useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Page } from "zmp-ui";
import BottomNav, { TabKey } from "../components/BottomNav";
import Icon from "../components/Icon";
import { uiState, useOpsSummary, useTaskData, useUnreadPolling } from "../data";
import MeTab from "./tabs/me-tab";
import OpsTab from "./tabs/ops-tab";
import OverviewTab from "./tabs/overview-tab";
import SummaryTab from "./tabs/summary-tab";
import TasksTab from "./tabs/tasks-tab";

const ORDER: TabKey[] = ["overview", "tasks", "ops", "summary", "me"];

/**
 * One shell for the three main tabs: the bottom bar stays put and only the panel content cross-fades,
 * instead of every tab being a separate animated route.
 */
export default function HomePage() {
  const nav = useNavigate();
  const data = useTaskData();
  useUnreadPolling();
  const ops = useOpsSummary();
  const [tab, setTabState] = useState<TabKey>(uiState.tab);
  const [jump, setJump] = useState<{ store: string; nonce: number } | null>(null);
  const [fabHidden, setFabHidden] = useState(false);
  const [fabPressed, setFabPressed] = useState(false);
  const lastScroll = useRef(0);

  const current: TabKey = tab === "summary" && !data.canManage ? "tasks" : tab;
  const setTab = (t: TabKey) => { uiState.tab = t; setTabState(t); };
  const activeIndex = ORDER.indexOf(current);

  // Slide the + button away while scrolling down, bring it back on scroll up.
  const onTasksScroll = (e: React.UIEvent<HTMLDivElement>) => {
    const top = e.currentTarget.scrollTop;
    const delta = top - lastScroll.current;
    if (Math.abs(delta) > 6) {
      setFabHidden(delta > 0 && top > 60);
      lastScroll.current = top;
    }
  };

  const openNewTask = () => {
    setFabPressed(true);
    setTimeout(() => {
      setFabPressed(false);
      nav("/new");
    }, 170);
  };

  const panel = (key: TabKey, children: React.ReactNode, onScroll?: (e: React.UIEvent<HTMLDivElement>) => void) => {
    const idx = ORDER.indexOf(key);
    const state = idx === activeIndex ? "active" : idx < activeIndex ? "left" : "right";
    return (
      <div className={`tab-panel ${state}`} aria-hidden={idx !== activeIndex} onScroll={onScroll}>
        {children}
      </div>
    );
  };

  return (
    <Page className="shell-page disable-scrolling">
      {panel("overview", <OverviewTab active={current === "overview"} />)}
      {panel("tasks", <TasksTab {...data} jump={jump} />, onTasksScroll)}
      {panel("ops", <OpsTab active={current === "ops"} />)}
      {data.canManage && panel("summary", (
        <SummaryTab
          active={current === "summary"}
          onOpenStore={(store) => { setJump({ store, nonce: Date.now() }); setTab("tasks"); }}
        />
      ))}
      {panel("me", <MeTab tasks={data.tasks} />)}

      {data.canManage && current === "tasks" && (
        <button
          className={`fab ${fabHidden ? "hidden" : ""} ${fabPressed ? "pressed" : ""}`}
          onClick={openNewTask}
          aria-label="Giao việc mới"
          title="Giao việc"
        >
          <Icon name="plus" size={28} />
        </button>
      )}
      <BottomNav
        tab={current}
        canManage={data.canManage}
        opsBadge={ops ? (ops.fund.reportedToday ? 0 : 1) + ops.board.unread + ops.orders.pendingApproval + (ops.fund.pendingReview || 0) : 0}
        onChange={setTab}
      />
    </Page>
  );
}
