using Flowtime.Services;

void test_four_phases_and_crossings () {
    bool crossed = false;

    // 1. WORK with balance >= 0 (earning credit)
    int64 b = Flowtime.Services.Timer.advance_ledger (0, TimerMode.WORK, 3600000, 0.33, out crossed);
    assert (b == 3600000);
    assert (!crossed);
    assert (Flowtime.Services.Timer.format_balance_string (b, TimerMode.WORK, 0.33) == "Break credit: +19m 48s");

    // 2. BREAK spending credit without crossing
    b = Flowtime.Services.Timer.advance_ledger (b, TimerMode.BREAK, 300000, 0.33, out crossed);
    assert (!crossed);
    assert (Flowtime.Services.Timer.format_balance_string (b, TimerMode.BREAK, 0.33) == "Break credit: +14m 48s");

    // 3. BREAK exact-boundary zero commit (dt_ms == exhaust_ms)
    int64 exhaust_ms = (int64) Math.round ((double) b * 0.33);
    int64 b_zero = Flowtime.Services.Timer.advance_ledger (b, TimerMode.BREAK, exhaust_ms, 0.33, out crossed);
    assert (b_zero == 0);
    assert (crossed);

    // 4. BREAK overrun into work debt (5m credit + 1m 15s overrun = 6m 15s)
    b = Flowtime.Services.Timer.advance_ledger (b, TimerMode.BREAK, exhaust_ms + 75000, 0.33, out crossed);
    assert (b == -75000);
    assert (crossed);
    assert (Flowtime.Services.Timer.format_balance_string (b, TimerMode.BREAK, 0.33) == "Over break · Work debt: 3m 47s");
    assert (Flowtime.Services.Timer.format_balance_string (b, TimerMode.WORK, 0.33) == "Work debt left: 3m 47s");

    // 5. WORK exact-boundary zero commit (dt_ms == clear_ms)
    int64 clear_ms = (int64) Math.round ((double) (-b) / 0.33);
    b_zero = Flowtime.Services.Timer.advance_ledger (b, TimerMode.WORK, clear_ms, 0.33, out crossed);
    assert (b_zero == 0);
    assert (crossed);

    // 6. WORK paying down debt and crossing into credit
    b = Flowtime.Services.Timer.advance_ledger (b, TimerMode.WORK, clear_ms + 60000, 0.33, out crossed);
    assert (b == 60000);
    assert (crossed);
}

void test_percentage_rescaling () {
    int64 work_ms = 3600000;
    assert (Flowtime.Services.Timer.format_balance_string (work_ms, TimerMode.WORK, 0.33) == "Break credit: +19m 48s");
    assert (Flowtime.Services.Timer.format_balance_string (work_ms, TimerMode.WORK, 0.50) == "Break credit: +30m 00s");
    assert (Flowtime.Services.Timer.format_balance_string (work_ms, TimerMode.WORK, 0.33) == "Break credit: +19m 48s");

    int64 overrun_ms = -60000;
    assert (Flowtime.Services.Timer.format_balance_string (overrun_ms, TimerMode.WORK, 0.33) == "Work debt left: 3m 02s");
    assert (Flowtime.Services.Timer.format_balance_string (overrun_ms, TimerMode.WORK, 0.50) == "Work debt left: 2m 00s");
}

void test_reset_boundaries () {
    var wed_late = new DateTime.local (2026, 11, 11, 23, 50, 0);
    var thu_early = new DateTime.local (2026, 11, 12, 0, 20, 0);

    var b_daily_wed = Flowtime.Services.Timer.compute_most_recent_boundary (wed_late, "daily", "monday", 0);
    var b_daily_thu = Flowtime.Services.Timer.compute_most_recent_boundary (thu_early, "daily", "monday", 0);
    assert (b_daily_wed != null && b_daily_thu != null);
    assert (b_daily_wed.get_day_of_month () == 11);
    assert (b_daily_thu.get_day_of_month () == 12);

    var early_330 = new DateTime.local (2026, 11, 12, 3, 30, 0);
    var b_custom = Flowtime.Services.Timer.compute_most_recent_boundary (early_330, "daily", "monday", 4);
    assert (b_custom.get_day_of_month () == 11);
    assert (b_custom.get_hour () == 4);

    var b_mon = Flowtime.Services.Timer.compute_most_recent_boundary (thu_early, "weekly", "monday", 0);
    assert (b_mon.get_day_of_week () == 1);
    assert (b_mon.get_day_of_month () == 9);

    var b_sun = Flowtime.Services.Timer.compute_most_recent_boundary (thu_early, "weekly", "sunday", 0);
    assert (b_sun.get_day_of_week () == 7);
    assert (b_sun.get_day_of_month () == 8);

    assert (Flowtime.Services.Timer.compute_most_recent_boundary (thu_early, "off", "monday", 0) == null);

    // Delayed reset callback: 30m debt at 23:50, work 23:50-00:20 (pre=10m, post=20m)
    int64 initial_debt_ms = -594000;
    int64 result_ms = Flowtime.Services.Timer.advance_ledger_across_reset (
        initial_debt_ms, TimerMode.WORK, 600000, 1200000, 0.33
    );
    assert (result_ms == 1200000);
    assert (Flowtime.Services.Timer.format_balance_string (result_ms, TimerMode.WORK, 0.33) == "Break credit: +6m 36s");
}

void test_progressive_formatting () {
    assert (Flowtime.Services.Timer.format_duration_seconds (0) == "0s");
    assert (Flowtime.Services.Timer.format_duration_seconds (45) == "45s");
    assert (Flowtime.Services.Timer.format_duration_seconds (725) == "12m 05s");
    assert (Flowtime.Services.Timer.format_duration_seconds (4500) == "1h 15m 00s");
    assert (Flowtime.Services.Timer.format_duration_seconds (95410) == "1d 02h 30m 10s");
}

void test_timer_lifecycle_and_resets () {
    var settings = new Flowtime.Services.Settings ();
    settings.carry_balance = true;
    settings.break_percentage = 33.0;
    settings.auto_reset_debt_policy = "daily";
    settings.reset_hour = 0;

    var timer = new Flowtime.Services.Timer ();
    timer.reset_work_debt ();
    timer.reset_break_credit ();
    assert (timer.committed_balance_ms == 0);
    assert (timer.mode == TimerMode.WORK);

    timer.start ();
    assert (timer.running);
    timer.stop ();
    assert (!timer.running);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/flowork/timer/four_phases_and_crossings", test_four_phases_and_crossings);
    Test.add_func ("/flowork/timer/percentage_rescaling", test_percentage_rescaling);
    Test.add_func ("/flowork/timer/reset_boundaries", test_reset_boundaries);
    Test.add_func ("/flowork/timer/progressive_formatting", test_progressive_formatting);
    Test.add_func ("/flowork/timer/lifecycle_and_resets", test_timer_lifecycle_and_resets);
    return Test.run ();
}
