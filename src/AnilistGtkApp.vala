/* AniListGtkApp.vala
 *
 * Copyright 2021 Laurin Neff <laurin@laurinneff.ch>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace AnilistGtk {
    public class AnilistGtkApp : Gtk.Application {
        public static AnilistGtkApp instance {get; private set;}

        public Settings settings {get; private set;}
        public AnilistClient client {get; private set;}

        protected AnilistGtkApp() {
            Object (application_id: "ch.laurinneff.AniList-GTK", flags: ApplicationFlags.HANDLES_OPEN);
            AnilistGtkApp.instance = this;
            settings = new GLib.Settings ("ch.laurinneff.AniList-GTK");
        }

        protected override void activate() {
            add_actions();

            client = new AnilistClient(this);

            hold();
            client.get_token.begin((obj, async_res) => {
                client.get_token.end(async_res);
                release();

                if(client.anilist_token == null) {
                    open_login_window();
                } else {
                    open_main_window();
                }
            });

            var style_provider = new Gtk.CssProvider();
            style_provider.load_from_resource("/ch/laurinneff/AniList-GTK/css/blur.css");
            Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        public override void open (File[] files, string hint) {
		    // NOTE: when doing a longer-lasting action here that returns
		    //  to the mainloop, you should use g_application_hold() and
		    //  g_application_release() to keep the application alive until
		    //  the action is completed.

		    foreach (File file in files) {
                if(file.get_uri_scheme() == "anilist-gtk") {
                    try {
                        var uri = Uri.parse(file.get_uri(), UriFlags.NONE);
                        var params = Uri.parse_params(uri.get_fragment());

                        client.store_token.begin (params.get("access_token"), (obj, res) => {
                            client.store_token.end (res);
                            if(active_window is LoginWindow) {
                                active_window.close();
                                open_main_window();
                            }
                        });
                    } catch(UriError e) {
                        error("can't parse uri: %s", e.message);
                    }
                } else {
                    error("unknown uri scheme");
                }
		    }
	    }

        protected void add_actions() {
            var quit_action = new SimpleAction("quit", null);
            quit_action.activate.connect(() => {
                active_window.destroy();
            });
            set_accels_for_action("app.quit", {"<Control>q", "<Control>w"});
            add_action(quit_action);

            var about_action = new SimpleAction("about", null);
            about_action.activate.connect(() => {
                var dialog = new Gtk.AboutDialog() {
                    program_name = _("AniList-GTK"),
                    logo_icon_name = "anilist-gtk",
                    authors = { "Laurin Neff" },
                    license_type = Gtk.License.GPL_3_0,
                    copyright = "© 2021 Laurin Neff",
                    modal = true,
                    transient_for = active_window,
                };
                dialog.present();
            });
            add_action(about_action);

            var accels_action = new SimpleAction("accels", null);
            accels_action.activate.connect(() => {
                message("show accels window");
            });
            set_accels_for_action("app.accels", {"F1", "<Control>question"});
            add_action(accels_action);

            var settings_action = new SimpleAction("settings", null);
            settings_action.activate.connect(() => {
                message("show settings window");
            });
            set_accels_for_action("app.settings", {"<Control>comma"});
            add_action(settings_action);

            var logout_action = new SimpleAction("logout", null);
            logout_action.activate.connect(() => {
                client.delete_token.begin();
                active_window.destroy();
                open_login_window();
            });
            add_action(logout_action);

            set_accels_for_action("win.back", {"<Alt>Left", "Back"});
        }

        protected void open_login_window() {
            message("open login window");
            var win = new LoginWindow(this);
            win.present();
        }

        protected void open_main_window() {
            var win = active_window;
            if(win == null) {
                win = new MainWindow(this);
            }
            win.present();
        }

        public static int main(string[] args) {
            return new AnilistGtkApp().run(args);
        }
    }
}

