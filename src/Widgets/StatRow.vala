/* StatRow.vala
 *
 * Copyright 2022-2023 Diego Iván <diegoivan.mae@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Flowtime {
    [GtkTemplate (ui = "/io/github/raameshb/flowork/statrow.ui")]
    public class StatRow : Adw.Bin {
        [GtkChild]
        private unowned Gtk.Label date_label;
        [GtkChild]
        private unowned Gtk.Label time_label;

        public string date {
            get {
                return date_label.label;
            }
            set {
                date_label.label = value;
            }
        }

        public string time {
            get {
                return time_label.label;
            }
            set {
                time_label.label = value;
            }
        }
    }
}
