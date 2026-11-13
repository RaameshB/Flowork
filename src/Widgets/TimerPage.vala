/* TimerPage.vala
 *
 * Copyright 2022-2023 Diego Iván <diegoivan.mae@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Flowtime {
    [GtkTemplate (ui = "/io/github/raameshb/flowork/timerpage.ui")]
    public class TimerPage : Adw.Bin {
        [GtkChild]
        private unowned Gtk.Button pause_button;
        [GtkChild]
        private unowned Gtk.Label time_label;
        [GtkChild]
        private unowned Gtk.Label stage_label;
        [GtkChild]
        private unowned Gtk.Label balance_pill;

        public Services.Timer _timer;
        public Services.Timer timer {
            get {
                return _timer;
            }
            set {
                _timer = value;
                timer.bind_property ("formatted-time", time_label, "label", SYNC_CREATE);
                timer.bind_property ("formatted-balance", balance_pill, "label", SYNC_CREATE);

                timer.notify["running"].connect (on_running_changed);
                timer.notify["mode"].connect (update_labels);
                timer.notify["phase"].connect (update_phase_classes);

                on_running_changed ();
                update_labels ();
                update_phase_classes ();
            }
        }

        public uint seconds {
            get {
                return timer.seconds;
            }
        }

        private void update_labels () {
            if (timer.mode == WORK) {
                stage_label.label = _("Work Stage");
                return;
            }
            stage_label.label = _("Break Stage");
        }

        private void update_phase_classes () {
            balance_pill.remove_css_class ("warning");
            balance_pill.remove_css_class ("success");
            balance_pill.remove_css_class ("error");

            switch (timer.phase) {
                case WORK_PAYING_DEBT:
                    balance_pill.add_css_class ("warning");
                    break;
                case WORK_EARNING_CREDIT:
                case BREAK_SPENDING_CREDIT:
                    balance_pill.add_css_class ("success");
                    break;
                case BREAK_OVERRUN_DEBT:
                    balance_pill.add_css_class ("error");
                    break;
            }
        }

        private void on_running_changed () {
            if (timer.running) {
                pause_button.icon_name = "media-playback-pause-symbolic";
                pause_button.tooltip_text = _("Pause Timer");
                return;
            }
            pause_button.icon_name = "media-playback-start-symbolic";
            pause_button.tooltip_text = _("Start Timer");
        }

        [GtkCallback]
        private void on_pause_button_clicked () {
            if (timer.running) {
                timer.stop ();
                return;
            }
            timer.start ();
        }

        [GtkCallback]
        private void on_next_button_clicked () {
            timer.next_mode ();
        }
    }
}
