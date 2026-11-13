using Flowtime.Services;
using Flowtime.Models;

void test_midnight_split_and_year_matching () {
    var tmp_dir = DirUtils.make_tmp ("flowork-stats-XXXXXX");
    Environment.set_variable ("XDG_DATA_HOME", tmp_dir, true);

    var stats = new Statistics ();
    assert (stats.today != null);

    // Same day of year across different years must not match
    var d_2025 = new DateTime.local (2025, 11, 12, 12, 0, 0);
    var d_2026 = new DateTime.local (2026, 11, 12, 12, 0, 0);
    assert (!Statistics.same_local_day (d_2025, d_2026));

    // Cross-midnight 30-minute session: 23:50 -> 00:20
    var end_dt = new DateTime.local (2026, 11, 12, 0, 20, 0);
    stats.add_time_to_mode (TimerMode.WORK, 1800, end_dt);

    var day_before = stats.ensure_day_for (new DateTime.local (2026, 11, 11, 23, 50, 0));
    var day_after = stats.ensure_day_for (end_dt);
    assert (day_before.worktime == 600);
    assert (day_after.worktime == 1200);
    assert (stats.total.worktime == 1800);
}

void test_pause_across_midnight_and_idempotency () {
    var tmp_dir = DirUtils.make_tmp ("flowork-stats-XXXXXX");
    Environment.set_variable ("XDG_DATA_HOME", tmp_dir, true);

    var stats = new Statistics ();
    int before_total = stats.total.worktime;

    // Work 23:40-23:50 (600s), pause at 23:50, then switch stages at 00:20
    var t_2350 = new DateTime.local (2026, 11, 5, 23, 50, 0);
    var t_0020 = new DateTime.local (2026, 11, 6, 0, 20, 0);

    var timer = new Flowtime.Services.Timer ();
    timer.add_test_session_ms (600000);
    timer.stop (t_2350);

    // Idempotent subsequent save/switch at 00:20 must not attribute 600s to Nov 6
    timer.save_to_statistics (t_0020);
    timer.next_mode ();

    var nov_05 = stats.ensure_day_for (t_2350);
    var nov_06 = stats.ensure_day_for (t_0020);
    assert (nov_05.worktime == 600);
    assert (nov_06.worktime == 0);
    assert (stats.total.worktime == before_total + 600);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/flowork/statistics/midnight_split_and_year_matching", test_midnight_split_and_year_matching);
    Test.add_func ("/flowork/statistics/pause_across_midnight_and_idempotency", test_pause_across_midnight_and_idempotency);
    return Test.run ();
}
