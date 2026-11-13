/* Settings.vala
 *
 * Copyright 2022-2023 Diego Iván <diegoivan.mae@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

[SingleInstance]
public class Flowtime.Services.Settings : Object {
    private GLib.Settings settings = new GLib.Settings (Config.APP_ID);

    private int _months_saved;
    public int months_saved {
        get {
            return _months_saved;
        }
        set {
            if (value > 6 || value < 0) {
                critical ("Value for months saved is out of range");
                return;
            }
            _months_saved = value;
        }
    }

    private double _break_percentage;
    public double break_percentage {
        get {
            return _break_percentage;
        }
        set {
            if (value < 10 || value > 100) {
                critical ("Break percentage is out of bounds");
                return;
            }
            _break_percentage = value;
        }
    }

    private int _reset_hour;
    public int reset_hour {
        get {
            return _reset_hour;
        }
        set {
            if (value < 0 || value > 23) {
                critical ("Reset hour is out of bounds");
                return;
            }
            _reset_hour = value;
        }
    }

    public string tone { get; set; }
    public bool autostart { get; set; }
    public bool distraction_free { get; set; }
    public bool activate_screensaver { get; set; }

    public bool keep_running_in_background { get; set; }
    public bool carry_balance { get; set; }
    public int64 balance_ms { get; set; }
    public string auto_reset_debt_policy { get; set; }
    public string weekly_reset_day { get; set; }
    public int64 last_debt_reset_utc { get; set; }
    public bool alert_break_exhausted { get; set; }
    public bool alert_debt_cleared { get; set; }

    private static Settings? instance = null;
    public Settings () {
        if (instance == null) {
            instance = this;
        }
    }

    construct {
        settings.bind ("tone", this, "tone", DEFAULT);
        settings.bind ("autostart", this, "autostart", DEFAULT);
        settings.bind ("distraction-free", this, "distraction-free", DEFAULT);
        settings.bind ("months-saved", this, "months-saved", DEFAULT);
        settings.bind ("break-percentage", this, "break-percentage", DEFAULT);
        settings.bind ("activate-screensaver", this, "activate-screensaver", DEFAULT);

        settings.bind ("keep-running-in-background", this, "keep-running-in-background", DEFAULT);
        settings.bind ("carry-balance", this, "carry-balance", DEFAULT);
        settings.bind ("balance-ms", this, "balance-ms", DEFAULT);
        settings.bind ("auto-reset-debt-policy", this, "auto-reset-debt-policy", DEFAULT);
        settings.bind ("weekly-reset-day", this, "weekly-reset-day", DEFAULT);
        settings.bind ("reset-hour", this, "reset-hour", DEFAULT);
        settings.bind ("last-debt-reset-utc", this, "last-debt-reset-utc", DEFAULT);
        settings.bind ("alert-break-exhausted", this, "alert-break-exhausted", DEFAULT);
        settings.bind ("alert-debt-cleared", this, "alert-debt-cleared", DEFAULT);
    }

    public void save () {
        GLib.Settings.sync ();
    }
}
