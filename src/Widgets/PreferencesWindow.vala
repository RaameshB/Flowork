/* PreferencesWindow.vala
 *
 * Copyright 2021-2023 Diego Iván <diegoivan.mae@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Flowtime {
    [GtkTemplate (ui = "/io/github/raameshb/flowork/preferenceswindow.ui")]
    public class PreferencesWindow : Adw.PreferencesDialog {
        [GtkChild]
        private unowned Adw.PreferencesGroup sounds_group;
        [GtkChild]
        private unowned Gtk.Switch autostart_switch;
        [GtkChild]
        private unowned Adw.SpinRow months_spinrow;
        [GtkChild]
        private unowned Adw.SpinRow percentage_spinrow;
        [GtkChild]
        private unowned Adw.SwitchRow screensaver_row;

        [GtkChild]
        private unowned Adw.SwitchRow keep_running_row;
        [GtkChild]
        private unowned Adw.SwitchRow carry_balance_row;
        [GtkChild]
        private unowned Adw.ComboRow auto_reset_row;
        [GtkChild]
        private unowned Adw.ComboRow weekly_day_row;
        [GtkChild]
        private unowned Adw.SpinRow reset_hour_row;
        [GtkChild]
        private unowned Adw.SwitchRow alert_debt_cleared_row;
        [GtkChild]
        private unowned Adw.SwitchRow alert_break_exhausted_row;
        [GtkChild]
        private unowned Adw.ActionRow reset_debt_row;
        [GtkChild]
        private unowned Gtk.Button reset_debt_button;
        [GtkChild]
        private unowned Adw.ActionRow reset_credit_row;
        [GtkChild]
        private unowned Gtk.Button reset_credit_button;

        private Services.Settings settings = new Services.Settings ();

        public Services.Screensaver? screensaver { get; construct; default = null; }
        public Services.Timer? timer { get; construct; default = null; }

        public PreferencesWindow (Gtk.Window? parent, Services.Screensaver? screensaver, Services.Timer? timer = null) {
            Object (screensaver: screensaver, timer: timer);
            present (parent);
        }

        construct {
            Gtk.CheckButton? button_group = null;
            months_spinrow.value = 0;

            settings.bind_property ("autostart",
                autostart_switch, "active",
                SYNC_CREATE | BIDIRECTIONAL
            );

            settings.bind_property ("months-saved",
                months_spinrow, "value",
                SYNC_CREATE | BIDIRECTIONAL
            );

            settings.bind_property ("activate-screensaver",
                                    screensaver_row, "active",
                                    SYNC_CREATE | BIDIRECTIONAL);

            settings.bind_property ("break-percentage",
                                    percentage_spinrow, "value",
                                    SYNC_CREATE | BIDIRECTIONAL);

            settings.bind_property ("keep-running-in-background",
                                    keep_running_row, "active",
                                    SYNC_CREATE | BIDIRECTIONAL);

            settings.bind_property ("carry-balance",
                                    carry_balance_row, "active",
                                    SYNC_CREATE | BIDIRECTIONAL);

            settings.bind_property ("reset-hour",
                                    reset_hour_row, "value",
                                    SYNC_CREATE | BIDIRECTIONAL);

            settings.bind_property ("alert-debt-cleared",
                                    alert_debt_cleared_row, "active",
                                    SYNC_CREATE | BIDIRECTIONAL);

            settings.bind_property ("alert-break-exhausted",
                                    alert_break_exhausted_row, "active",
                                    SYNC_CREATE | BIDIRECTIONAL);

            // Auto-reset policy combo: 0=daily, 1=weekly, 2=off
            switch (settings.auto_reset_debt_policy) {
                case "weekly":
                    auto_reset_row.selected = 1;
                    break;
                case "off":
                    auto_reset_row.selected = 2;
                    break;
                default:
                    auto_reset_row.selected = 0;
                    break;
            }
            weekly_day_row.sensitive = (auto_reset_row.selected == 1);
            reset_hour_row.sensitive = (auto_reset_row.selected != 2);

            auto_reset_row.notify["selected"].connect (() => {
                switch (auto_reset_row.selected) {
                    case 1:
                        settings.auto_reset_debt_policy = "weekly";
                        break;
                    case 2:
                        settings.auto_reset_debt_policy = "off";
                        break;
                    default:
                        settings.auto_reset_debt_policy = "daily";
                        break;
                }
                weekly_day_row.sensitive = (auto_reset_row.selected == 1);
                reset_hour_row.sensitive = (auto_reset_row.selected != 2);
            });

            // Weekly reset day combo: 0=monday, 1=sunday
            weekly_day_row.selected = (settings.weekly_reset_day == "sunday") ? 1 : 0;
            weekly_day_row.notify["selected"].connect (() => {
                settings.weekly_reset_day = (weekly_day_row.selected == 1) ? "sunday" : "monday";
            });

            reset_debt_row.activated.connect (() => {
                if (timer != null) {
                    timer.reset_work_debt ();
                }
            });
            reset_debt_button.clicked.connect (() => {
                if (timer != null) {
                    timer.reset_work_debt ();
                }
            });

            reset_credit_row.activated.connect (() => {
                if (timer != null) {
                    timer.reset_break_credit ();
                }
            });
            reset_credit_button.clicked.connect (() => {
                if (timer != null) {
                    timer.reset_break_credit ();
                }
            });

            var tone_player = new Services.TonePlayer ();
            foreach (unowned string key in tone_player.get_tone_keys ()) {
                var row = new SoundRow (key);
                if (button_group == null) {
                    button_group = row.check_button;
                }

                row.check_button.group = button_group;

                if (row.tone_key == settings.tone) {
                    row.check_button.active = true;
                }

                sounds_group.add (row);
            }

            screensaver_row.visible = screensaver == null ? false : screensaver.supported;
        }
    }
}
