import React, { useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Page } from "zmp-ui";
import BottomNav, { TabKey } from "../components/BottomNav";
import Icon from "../components/Icon";
import { bumpData, refreshOps, uiState, useOpsSummary, useTaskData, useUnreadPolling } from "../data";
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
  const [pull, setPull] = useState(0);
  const [refreshing, setRefreshing] = useState(false);
  const touchStart = useRef<number | null>(null);

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

  // Pull down from the top of any tab to reload its data (replaces the old refresh buttons).
  const PULL_TRIGGER = 64;
  const onTouchStart = (e: React.TouchEvent<HTMLDivElement>) => {
    touchStart.current = e.currentTarget.scrollTop <= 0 && !refreshing ? e.touches[0].clientY : null;
  };
  const onTouchMove = (e: React.TouchEvent<HTMLDivElement>) => {
    if (touchStart.current == null) return;
    const dy = e.touches[0].clientY - touchStart.current;
    if (dy > 0 && e.currentTarget.scrollTop <= 0) setPull(Math.min(dy * 0.5, 96));
    else if (dy <= 0) setPull(0);
  };
  const onTouchEnd = async () => {
    const go = touchStart.current != null && pull >= PULL_TRIGGER;
    touchStart.current = null;
    if (!go) return setPull(0);
    setRefreshing(true);
    setPull(PULL_TRIGGER);
    bumpData();
    await Promise.all([refreshOps(), new Promise((r) => setTimeout(r, 800))]);
    setRefreshing(false);
    setPull(0);
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
      <div
        className={`tab-panel ${state}`}
        aria-hidden={idx !== activeIndex}
        onScroll={onScroll}
        onTouchStart={idx === activeIndex ? onTouchStart : undefined}
        onTouchMove={idx === activeIndex ? onTouchMove : undefined}
        onTouchEnd={idx === activeIndex ? onTouchEnd : undefined}
        onTouchCancel={idx === activeIndex ? onTouchEnd : undefined}
      >
        {children}
      </div>
    );
  };

  return (
    <Page className="shell-page disable-scrolling">
      <div className={`ptr ${pull > 0 || refreshing ? "show" : ""} ${refreshing ? "spin" : ""}`} style={{ transform: `translate(-50%, ${pull - 44}px)` }} aria-hidden>
        <Icon name="refresh" size={20} className="ptr-ico" />
      </div>
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
