/* Timer.vala
 *
 * Copyright 2022-2023 Diego Iván <diegoivan.mae@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

[DBus (name = "org.freedesktop.login1.Manager")]
private interface Flowtime.Services.Login1Manager : Object {
    public signal void prepare_for_sleep (bool start);
}

public class Flowtime.Services.Timer : Object {
    public bool running { get; protected set; default = false; }

    private int _seconds;
    public int seconds {
        get {
            return _seconds;
        }
        protected set {
            _seconds = value;
            formatted_time = format_duration_seconds (_seconds);
            updated ();
        }
    }

    public bool is_used {
        get {
            return running || session_elapsed_ms > 0;
        }
    }

    public TimerMode mode { get; private set; default = WORK; }
    public TimerPhase phase { get; private set; default = WORK_EARNING_CREDIT; }
    public string formatted_time { get; private set; default = "0s"; }
    public string formatted_balance { get; private set; default = "Break credit: +0s"; }

    public int64 committed_balance_ms { get; private set; default = 0; }

    public signal void updated ();
    public signal void break_credit_exhausted ();
    public signal void work_debt_cleared ();
    public signal void toast_requested (string message);

    private const int INTERVAL_MILLISECONDS = 250;
    private uint? timeout_id = null;
    private uint? reset_timeout_id = null;

    private int64 anchor_mono_ms = 0;
    private int64 session_elapsed_ms = 0;
    private int flushed_session_seconds = 0;
    private double last_r = 0.33;
    private bool crossing_notified_in_stretch = false;

    private Settings settings;
    private Login1Manager? login1_proxy = null;

    ~Timer () {
        stop ();
        save_to_statistics ();
        clear_reset_timeout ();
    }

    construct {
        settings = new Settings ();
        last_r = settings.break_percentage / 100.0;

        if (settings.carry_balance) {
            committed_balance_ms = settings.balance_ms;
        } else {
            committed_balance_ms = 0;
        }

        var now_local = new DateTime.now_local ();
        if (settings.last_debt_reset_utc == 0) {
            settings.last_debt_reset_utc = now_local.to_utc ().to_unix () * 1000;
        }

        apply_due_resets (now_local, false);
        refresh_display (committed_balance_ms, 0);
        schedule_reset_timeout ();

        settings.notify["break-percentage"].connect (on_break_percentage_changed);
        settings.notify["auto-reset-debt-policy"].connect (() => schedule_reset_timeout ());
        settings.notify["weekly-reset-day"].connect (() => schedule_reset_timeout ());
        settings.notify["reset-hour"].connect (() => schedule_reset_timeout ());

        init_login1.begin ();
    }

    private async void init_login1 () {
        try {
            login1_proxy = yield Bus.get_proxy<Login1Manager> (
                BusType.SYSTEM,
                "org.freedesktop.login1",
                "/org/freedesktop/login1"
            );
            login1_proxy.prepare_for_sleep.connect (on_prepare_for_sleep);
        } catch (Error e) {
            debug ("login1 PrepareForSleep unavailable (fallback to CLOCK_MONOTONIC): %s", e.message);
        }
    }

    private void on_prepare_for_sleep (bool start_sleep) {
        if (start_sleep) {
            if (running) {
                stop ();
            }
        } else {
            apply_due_resets (new DateTime.now_local (), false);
            schedule_reset_timeout ();
            refresh_display (committed_balance_ms, session_elapsed_ms);
        }
    }

    private void on_break_percentage_changed () {
        if (running) {
            fold_active_segment ();
        }
        last_r = settings.break_percentage / 100.0;
        refresh_display (committed_balance_ms, session_elapsed_ms);
    }

    public void start () {
        if (running) {
            return;
        }
        apply_due_resets (new DateTime.now_local (), false);
        anchor_mono_ms = GLib.get_monotonic_time () / 1000;
        running = true;
        timeout_id = Timeout.add (INTERVAL_MILLISECONDS, timeout);
        refresh_display (committed_balance_ms, session_elapsed_ms);
    }

    public void stop (DateTime? end_local = null) {
        if (running) {
            fold_active_segment ();
            running = false;
        }
        if (timeout_id != null) {
            Source.remove (timeout_id);
            timeout_id = null;
        }
        save_to_statistics (end_local);
        persist_balance ();
        refresh_display (committed_balance_ms, session_elapsed_ms);
    }

    public void next_mode () {
        stop ();
        save_to_statistics ();

        session_elapsed_ms = 0;
        flushed_session_seconds = 0;
        crossing_notified_in_stretch = false;
        _seconds = 0;

        if (mode == WORK) {
            mode = BREAK;
            if (committed_balance_ms <= 0) {
                toast_requested (_("No break credit left — accruing work debt"));
            }
        } else {
            if (committed_balance_ms > 0) {
                int64 credit_sec = (int64) Math.round ((double) committed_balance_ms * last_r / 1000.0);
                if (credit_sec > 0) {
                    toast_requested (_("Saved %s of break credit for later").printf (format_duration_seconds (credit_sec)));
                }
            }
            mode = WORK;
        }

        refresh_display (committed_balance_ms, 0);

        if (settings.autostart) {
            start ();
        }
    }

    public void reset_work_debt () {
        if (running) {
            fold_active_segment ();
        }
        if (committed_balance_ms < 0) {
            committed_balance_ms = 0;
            crossing_notified_in_stretch = false;
            persist_balance ();
        }
        refresh_display (committed_balance_ms, session_elapsed_ms);
    }

    public void reset_break_credit () {
        if (running) {
            fold_active_segment ();
        }
        if (committed_balance_ms > 0) {
            committed_balance_ms = 0;
            crossing_notified_in_stretch = false;
            persist_balance ();
        }
        refresh_display (committed_balance_ms, session_elapsed_ms);
    }

    public void save_to_statistics (DateTime? end_local = null) {
        int current_sec = (int) (session_elapsed_ms / 1000);
        int delta = current_sec - flushed_session_seconds;
        if (delta <= 0) {
            return;
        }

        var statistics = new Statistics ();
        statistics.add_time_to_mode (mode, delta, end_local);
        flushed_session_seconds = current_sec;
    }

    public void add_test_session_ms (int64 ms) {
        session_elapsed_ms += ms;
    }

    private void persist_balance () {
        if (settings.carry_balance) {
            settings.balance_ms = committed_balance_ms;
        } else {
            settings.balance_ms = 0;
        }
    }

    private void fold_active_segment () {
        int64 now_mono_ms = GLib.get_monotonic_time () / 1000;
        int64 dt_ms = int64.max (0, now_mono_ms - anchor_mono_ms);
        anchor_mono_ms = now_mono_ms;

        if (dt_ms == 0) {
            return;
        }

        session_elapsed_ms += dt_ms;

        bool crossed = false;
        int64 prev = committed_balance_ms;
        committed_balance_ms = advance_ledger (prev, mode, dt_ms, last_r, out crossed);
        persist_balance ();

        if (crossed && !crossing_notified_in_stretch) {
            crossing_notified_in_stretch = true;
            if (mode == BREAK && prev > 0 && committed_balance_ms <= 0) {
                break_credit_exhausted ();
            } else if (mode == WORK && prev < 0 && committed_balance_ms >= 0) {
                work_debt_cleared ();
            }
        }
    }

    protected bool timeout () {
        if (!running) {
            return false;
        }

        int64 now_mono_ms = GLib.get_monotonic_time () / 1000;
        int64 dt_ms = int64.max (0, now_mono_ms - anchor_mono_ms);

        bool crossed = false;
        int64 live_balance = advance_ledger (committed_balance_ms, mode, dt_ms, last_r, out crossed);

        if (crossed && !crossing_notified_in_stretch) {
            fold_active_segment ();
            live_balance = committed_balance_ms;
            dt_ms = 0;
        }

        refresh_display (live_balance, session_elapsed_ms + dt_ms);
        return true;
    }

    private void refresh_display (int64 balance_ms, int64 total_session_ms) {
        if (mode == WORK) {
            phase = balance_ms < 0 ? TimerPhase.WORK_PAYING_DEBT : TimerPhase.WORK_EARNING_CREDIT;
        } else {
            phase = balance_ms > 0 ? TimerPhase.BREAK_SPENDING_CREDIT : TimerPhase.BREAK_OVERRUN_DEBT;
        }

        formatted_balance = format_balance_string (balance_ms, mode, last_r);
        seconds = (int) (total_session_ms / 1000);
    }

    private void clear_reset_timeout () {
        if (reset_timeout_id != null) {
            Source.remove (reset_timeout_id);
            reset_timeout_id = null;
        }
    }

    private void schedule_reset_timeout () {
        clear_reset_timeout ();

        if (settings.auto_reset_debt_policy == "off") {
            return;
        }

        var now_local = new DateTime.now_local ();
        var next_boundary = compute_next_boundary (
            now_local,
            settings.auto_reset_debt_policy,
            settings.weekly_reset_day,
            settings.reset_hour
        );

        if (next_boundary == null) {
            return;
        }

        int64 diff_us = next_boundary.difference (now_local);
        uint delay_sec = (uint) int64.max (1, (diff_us + TimeSpan.SECOND - 1) / TimeSpan.SECOND);

        reset_timeout_id = Timeout.add_seconds (delay_sec, () => {
            reset_timeout_id = null;
            on_reset_boundary_fired (next_boundary);
            return false;
        });
    }

    private void on_reset_boundary_fired (DateTime scheduled_boundary) {
        var now_local = new DateTime.now_local ();
        if (running) {
            int64 now_mono_ms = GLib.get_monotonic_time () / 1000;
            int64 total_dt_ms = int64.max (0, now_mono_ms - anchor_mono_ms);
            anchor_mono_ms = now_mono_ms;

            int64 post_ms = int64.min (total_dt_ms, int64.max (0, now_local.difference (scheduled_boundary) / 1000));
            int64 pre_ms = total_dt_ms - post_ms;

            fold_duration_ms (pre_ms);
            apply_due_resets (now_local, mode == WORK);
            fold_duration_ms (post_ms);
        } else {
            apply_due_resets (now_local, false);
        }
        refresh_display (committed_balance_ms, session_elapsed_ms);
        schedule_reset_timeout ();
    }

    private void fold_duration_ms (int64 dt_ms) {
        if (dt_ms <= 0) {
            return;
        }
        session_elapsed_ms += dt_ms;
        bool crossed = false;
        int64 prev = committed_balance_ms;
        committed_balance_ms = advance_ledger (prev, mode, dt_ms, last_r, out crossed);
        persist_balance ();

        if (crossed && !crossing_notified_in_stretch) {
            crossing_notified_in_stretch = true;
            if (mode == BREAK && prev > 0 && committed_balance_ms <= 0) {
                break_credit_exhausted ();
            } else if (mode == WORK && prev < 0 && committed_balance_ms >= 0) {
                work_debt_cleared ();
            }
        }
    }

    public static int64 advance_ledger_across_reset (int64 balance_ms, TimerMode mode, int64 pre_ms, int64 post_ms, double r) {
        bool ignored = false;
        int64 at_boundary = advance_ledger (balance_ms, mode, pre_ms, r, out ignored);
        if (at_boundary < 0) {
            at_boundary = 0;
        }
        return advance_ledger (at_boundary, mode, post_ms, r, out ignored);
    }

    private void apply_due_resets (DateTime now_local, bool allow_work_alert) {
        if (settings.auto_reset_debt_policy == "off") {
            return;
        }

        var boundary = compute_most_recent_boundary (
            now_local,
            settings.auto_reset_debt_policy,
            settings.weekly_reset_day,
            settings.reset_hour
        );
        if (boundary == null) {
            return;
        }

        int64 boundary_utc_ms = boundary.to_utc ().to_unix () * 1000;
        if (settings.last_debt_reset_utc < boundary_utc_ms) {
            bool had_debt = committed_balance_ms < 0;
            if (had_debt) {
                committed_balance_ms = 0;
                persist_balance ();
                if (allow_work_alert && !crossing_notified_in_stretch) {
                    crossing_notified_in_stretch = true;
                    work_debt_cleared ();
                }
            }
            settings.last_debt_reset_utc = boundary_utc_ms;
        }
    }

    // --- Pure testable helpers ---

    public static int64 advance_ledger (int64 balance_ms, TimerMode mode, int64 dt_ms, double r, out bool crossed) {
        crossed = false;
        if (dt_ms <= 0) {
            return balance_ms;
        }

        if (mode == TimerMode.WORK) {
            if (balance_ms >= 0) {
                return balance_ms + dt_ms;
            }
            int64 clear_ms = (int64) Math.round ((double) (-balance_ms) / r);
            if (dt_ms < clear_ms) {
                int64 next = int64.min (0, balance_ms + (int64) Math.round ((double) dt_ms * r));
                if (next == 0) {
                    crossed = true;
                }
                return next;
            } else if (dt_ms == clear_ms) {
                crossed = true;
                return 0;
            } else {
                crossed = true;
                return dt_ms - clear_ms;
            }
        } else {
            if (balance_ms <= 0) {
                return balance_ms - dt_ms;
            }
            int64 exhaust_ms = (int64) Math.round ((double) balance_ms * r);
            if (dt_ms < exhaust_ms) {
                int64 next = int64.max (0, balance_ms - (int64) Math.round ((double) dt_ms / r));
                if (next == 0) {
                    crossed = true;
                }
                return next;
            } else if (dt_ms == exhaust_ms) {
                crossed = true;
                return 0;
            } else {
                crossed = true;
                return -(dt_ms - exhaust_ms);
            }
        }
    }

    public static string format_duration_seconds (int64 total_seconds) {
        int64 s = total_seconds < 0 ? -total_seconds : total_seconds;
        int64 days = s / 86400;
        int64 hours = (s % 86400) / 3600;
        int64 mins = (s % 3600) / 60;
        int64 secs = s % 60;

        if (days > 0) {
            return "%lldd %02lldh %02lldm %02llds".printf (days, hours, mins, secs);
        }
        if (hours > 0) {
            return "%lldh %02lldm %02llds".printf (hours, mins, secs);
        }
        if (mins > 0) {
            return "%lldm %02llds".printf (mins, secs);
        }
        return "%llds".printf (secs);
    }

    public static string format_balance_string (int64 balance_ms, TimerMode mode, double r) {
        if (mode == TimerMode.WORK) {
            if (balance_ms < 0) {
                int64 debt_sec = (int64) Math.round ((double) (-balance_ms) / r / 1000.0);
                return _("Work debt left: %s").printf (format_duration_seconds (debt_sec));
            }
            int64 credit_sec = (int64) Math.round ((double) balance_ms * r / 1000.0);
            return _("Break credit: +%s").printf (format_duration_seconds (credit_sec));
        } else {
            if (balance_ms > 0) {
                int64 credit_sec = (int64) Math.round ((double) balance_ms * r / 1000.0);
                return _("Break credit: +%s").printf (format_duration_seconds (credit_sec));
            }
            int64 debt_sec = (int64) Math.round ((double) (-balance_ms) / r / 1000.0);
            return _("Over break · Work debt: %s").printf (format_duration_seconds (debt_sec));
        }
    }

    public static DateTime? compute_most_recent_boundary (DateTime now_local, string policy, string weekly_day, int reset_hour) {
        if (policy == "off") {
            return null;
        }

        var today_reset = new DateTime.local (
            now_local.get_year (),
            now_local.get_month (),
            now_local.get_day_of_month (),
            reset_hour,
            0,
            0
        );

        if (policy == "daily") {
            return now_local.compare (today_reset) >= 0 ? today_reset : today_reset.add_days (-1);
        }

        if (policy == "weekly") {
            int target_dow = weekly_day == "sunday" ? 7 : 1;
            int current_dow = now_local.get_day_of_week ();
            int days_back = (current_dow - target_dow + 7) % 7;
            var candidate = today_reset.add_days (-days_back);
            if (now_local.compare (candidate) < 0) {
                candidate = candidate.add_days (-7);
            }
            return candidate;
        }

        return null;
    }

    public static DateTime? compute_next_boundary (DateTime now_local, string policy, string weekly_day, int reset_hour) {
        var recent = compute_most_recent_boundary (now_local, policy, weekly_day, reset_hour);
        if (recent == null) {
            return null;
        }
        return policy == "weekly" ? recent.add_days (7) : recent.add_days (1);
    }
}

public enum Flowtime.Services.TimerMode {
    WORK,
    BREAK;

    public string to_string () {
        switch (this) {
            case WORK:
                return _("Work");
            case BREAK:
                return _("Break");
            default:
                assert_not_reached ();
        }
    }
}

public enum Flowtime.Services.TimerPhase {
    WORK_PAYING_DEBT,
    WORK_EARNING_CREDIT,
    BREAK_SPENDING_CREDIT,
    BREAK_OVERRUN_DEBT;
}
