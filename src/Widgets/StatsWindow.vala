/* StatsWindow.vala
 *
 * Copyright 2022-2023 Diego Iván <diegoivan.mae@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Flowtime {
    [GtkTemplate (ui = "/io/github/raameshb/flowork/statwindow.ui")]
    public class StatsWindow : Adw.Dialog {
        [GtkChild]
        private unowned StatList work_list;
        [GtkChild]
        private unowned StatList break_list;
        [GtkChild]
        private unowned Gtk.Button save_button;
        [GtkChild]
        private unowned Gtk.Stack content_stack;

        construct {
            var statistics = new Services.Statistics ();
            if (statistics.total.worktime == 0) {
                content_stack.visible_child_name = "empty";
                save_button.visible = false;
            }

            foreach (Models.Day day in statistics.all_days) {
                var work_object = new Models.StatObject (day.date, day.worktime);
                work_list.append (work_object);

                var break_object = new Models.StatObject (day.date, day.breaktime);
                break_list.append (break_object);
            }

            if (!statistics.all_days.is_empty ()) {
                work_list.description = _("%s is your most productive day of the week").printf (statistics.productive_day);
            }
        }

        public async void save_as_csv (File file) {
            var statistics = new Services.Statistics ();
            string format = "date,worktime,breaktime\n";
            foreach (Models.Day day in statistics.all_days) {
                var work_object = new Models.StatObject (day.date, day.worktime);
                var break_object = new Models.StatObject (day.date, day.breaktime);

                format += "\"%s\",\"%s\",\"%s\"\n".printf(work_object.date, work_object.time, break_object.time);
            }

            try {
                FileUtils.set_contents (file.get_path (), format);
            }
            catch (Error e) {
                critical (e.message);
            }
        }

        [GtkCallback]
        private void on_save_button_clicked () {
            save_action.begin ();
        }

        private async void save_action () {
            var csv_filter = new Gtk.FileFilter () {
                name = _("CSV files")
            };
            csv_filter.add_suffix ("csv");
            csv_filter.add_mime_type ("text/csv");

            var filters = new ListStore (typeof (Gtk.FileFilter));
            filters.append (csv_filter);

            var file_dialog = new Gtk.FileDialog () {
                modal = true,
                initial_name = "flowork-statistics.csv",
                filters = filters,
                default_filter = csv_filter
            };

            try {
                File file = yield file_dialog.save ((Gtk.Window) this.root, null);
                yield save_as_csv (file);
            }
            catch (Error e) {
                critical (e.message);
            }
        }
    }
}
