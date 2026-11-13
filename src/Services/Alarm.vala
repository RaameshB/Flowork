/* Alarm.vala
 *
 * Copyright 2022-2023 Diego Iván <diegoivan.mae@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Flowtime.Services.Alarm {
    private TonePlayer player = new TonePlayer ();
    private unowned GLib.Application application = GLib.Application.get_default ();

    private Timer _timer;
    public Timer timer {
        get {
            return _timer;
        }
        set {
            _timer = value;
            timer.break_credit_exhausted.connect (on_break_credit_exhausted);
            timer.work_debt_cleared.connect (on_work_debt_cleared);
        }
    }

    public Alarm (Timer timer) {
        this.timer = timer;
    }

    private void on_break_credit_exhausted () {
        var settings = new Settings ();
        if (!settings.alert_break_exhausted) {
            return;
        }

        var notification = new GLib.Notification (_("Break credit exhausted"));
        notification.set_body (_("You are now accruing work debt"));
        notification.set_priority (NORMAL);

        application.send_notification ("Flowork-Break-Exhausted", notification);
        player.play_tone (settings.tone);
    }

    private void on_work_debt_cleared () {
        var settings = new Settings ();
        if (!settings.alert_debt_cleared) {
            return;
        }

        var notification = new GLib.Notification (_("Work debt paid off"));
        notification.set_body (_("You are now earning break credit"));
        notification.set_priority (NORMAL);

        application.send_notification ("Flowork-Debt-Cleared", notification);
        player.play_tone (settings.tone);
    }
}
