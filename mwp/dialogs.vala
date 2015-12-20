/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */


extern void espeak_init(string voice);
extern void espeak_say(string text);


public class Units :  GLib.Object
{
    private const string [] dnames = {"m", "ft", "yd","fg"};
    private const string [] dspeeds = {"m/s", "kph", "mph", "kts", "fg/ft"};
    private const string [] dfix = {"no","","2d-","3d-"};


    public static double distance (double d)
    {
        switch(MWPlanner.conf.p_distance)
        {
            case 1:
                d *= 3.2808399;
                break;
            case 2:
                d *= 1.0936133;
                break;
//            case 3: //furlongs
//                d *= 0.0049709695;
//                break;
        }
        return d;
    }
    public static double speed (double d)
    {
        switch(MWPlanner.conf.p_speed)
        {
            case 1:
                d *= 3.6;
                break;
            case 2:
                d *= 2.2369363;
                break;
            case 3:
                d *= 1.9438445;
                break;
//            case 4: //furlongs / fortnight
//                d *= 6012.8848;
//                break;
        }
        return d;
    }

    public static double va_speed (double d)
    {
        if (MWPlanner.conf.p_speed > 1)
                d *= 3.2808399; // ft/sec
        return d;
    }

    public static string distance_units()
    {
        return dnames[MWPlanner.conf.p_distance];
    }

    public static string speed_units()
    {
        return dspeeds[MWPlanner.conf.p_speed];
    }

    public static string va_speed_units()
    {
        return (MWPlanner.conf.p_speed > 1) ? "ft/s" : "m/s";
    }

    public static string fix(uint8 fix)
    {
        return dfix[fix];
    }
}

public class ArtWin : GLib.Object
{
    public Gtk.Box  box {get; private set;}
    private Gtk.Socket socket;
    private uint sid;
    private int fdin;
    private int fdout;
    private static Pid apid = 0;
    private uint tag;

    public static void xchild()
    {
        if(apid != 0)
            Posix.kill(ArtWin.apid, Posix.SIGTERM);
    }

    public ArtWin()
    {
        atexit(ArtWin.xchild);
        box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        socket = new Gtk.Socket();
        box.pack_start(socket, true,true,0);
        box.show_all();
    }

    public void init()
    {
        string [] args = {"mwp_ath", "-p"};
        try {
            Process.spawn_async_with_pipes ("/",
                                            args,
                                            null,
                                            SpawnFlags.SEARCH_PATH,
                                            null,
                                            out apid,
                                            out fdin,
                                            out fdout,
                                            null);
        } catch  {}
        var io_read = new IOChannel.unix_new(fdout);
        tag = io_read.add_watch(IOCondition.IN|IOCondition.HUP|
                                    IOCondition.NVAL|IOCondition.ERR,
                                    plug_read);
    }

    private bool plug_read(IOChannel gio, IOCondition cond)
    {
        bool ret;
        if((cond & IOCondition.IN) == IOCondition.IN)
        {
            string buf;
            size_t length;
            size_t terminator_pos;
            try {
                gio.read_line (out buf, out length, out terminator_pos);
                sid = int.parse(buf);
                socket.add_id((X.Window)sid);
            } catch { }
            ret = true;
        }
        else
        {
            Source.remove(tag);
            ret = false;
        }
        return ret;
    }

    public void update(short sx, short sy, bool visible)
    {
        if(apid !=0 && visible)
        {
            double dx,dy;

            dx = -sx/10.0;
            if (dx < 0)
                dx += 360;

            dy = -sy/10;

            string s = "%.1f %.1f\n".printf(dx, dy);
            Posix.write(fdin, s, s.length);
        }
    }

    public void run()
    {
        if(apid == 0)
        {
            init();
        }
    }

}

public class TelemetryStats : GLib.Object
{
    private Gtk.Label elapsed;
    private Gtk.Label rxbytes;
    private Gtk.Label txbytes;
    private Gtk.Label rxrate;
    private Gtk.Label txrate;
    private Gtk.Label timeouts;
    private Gtk.Label waittime;
    private Gtk.Label cycletime;
    private Gtk.Label messages;
    public Gtk.Grid grid {get; private set;}

    public TelemetryStats(Gtk.Builder builder)
    {
        grid = builder.get_object ("ss_grid") as Gtk.Grid;
        elapsed = builder.get_object ("ss-elapsed") as Gtk.Label;
        rxbytes = builder.get_object ("ss-rxbytes") as Gtk.Label;
        txbytes = builder.get_object ("ss-txbytes") as Gtk.Label;
        rxrate = builder.get_object ("ss-rxrate") as Gtk.Label;
        txrate = builder.get_object ("ss-txrate") as Gtk.Label;
        timeouts = builder.get_object ("ss-timeout") as Gtk.Label;
        waittime = builder.get_object ("ss-wait") as Gtk.Label;
        cycletime = builder.get_object ("ss-cycle") as Gtk.Label;
        messages = builder.get_object ("ss-msgs") as Gtk.Label;
        grid.show_all();
    }


   public void annul()
   {
       elapsed.set_label("---");
       rxbytes.set_label("---");
       txbytes.set_label("---");
       rxrate.set_label("---");
       txrate.set_label("---");
       timeouts.set_label("---");
       waittime.set_label("---");
       cycletime.set_label("---");
       messages.set_label("---");
   }

   public void update(TelemStats t, bool visible)
    {
        if(visible)
        {
            elapsed.set_label("%.0f s".printf(t.s.elapsed));
            rxbytes.set_label("%lu b".printf(t.s.rxbytes));
            txbytes.set_label("%lu b".printf(t.s.txbytes));
            rxrate.set_label("%.0f b/s".printf(t.s.rxrate));
            txrate.set_label("%.0f b/s".printf(t.s.txrate));
            timeouts.set_label("%lu".printf(t.toc));
            waittime.set_label("%d ms".printf(t.tot));
            cycletime.set_label("%lu ms".printf(t.avg));
            messages.set_label(
                ("%" + uint64.FORMAT_MODIFIER + "d").printf(t.msgs));
        }
    }
}

public class FlightBox : GLib.Object
{
    private Gtk.Label big_lat;
    private Gtk.Label big_lon;
    private Gtk.Label big_rng;
    private Gtk.Label big_bearing;
    private Gtk.Label big_hdr;
    private Gtk.Label big_alt;
    private Gtk.Label big_spd;
    private Gtk.Label big_sats;
    public Gtk.Box vbox {get; private set;}

    public FlightBox(Gtk.Builder builder)
    {
        vbox = builder.get_object ("flight_box") as Gtk.Box;
        big_lat = builder.get_object ("big_lat") as Gtk.Label;
        big_lon = builder.get_object ("big_lon") as Gtk.Label;
        big_rng = builder.get_object ("big_rng") as Gtk.Label;
        big_bearing = builder.get_object ("big_bearing") as Gtk.Label;
        big_hdr = builder.get_object ("big_hdr") as Gtk.Label;
        big_alt = builder.get_object ("big_alt") as Gtk.Label;
        big_spd = builder.get_object ("big_spd") as Gtk.Label;
        big_sats = builder.get_object ("big_sats") as Gtk.Label;
        vbox.show_all();
    }

   public void annul()
   {
   }

   public void update(bool visible)
    {
        if(visible)
        {
            Gtk.Allocation a;
            vbox.get_allocation(out a);
            var fh1 = a.width/10;
            int fh2;
            fh2 = (MWPlanner.conf.dms) ? fh1*40/100 : fh1/2;
            var s=PosFormat.lat(GPSInfo.lat,MWPlanner.conf.dms);
            if(fh1 > 96)
                fh1 = 96;

            var fh3 = fh1;
            var falt = NavStatus.alti.estalt/100;

            if(falt > 9999.0 || falt < -999.0)
                fh3 = fh3 * 60/100;
            else if(falt > 999.0 || falt < -99.0)
                fh3 = fh3 * 75 /100;

            big_lat.set_label("<span font='%d'>%s</span>".printf(fh2,s));
            s=PosFormat.lon(GPSInfo.lon,MWPlanner.conf.dms);
            big_lon.set_label("<span font='%d'>%s</span>".printf(fh2,s));
            var brg = NavStatus.cg.direction;
            if(brg < 0)
                brg += 360;
            if(NavStatus.recip)
                brg = ((brg + 180) % 360);
            big_rng.set_label(
                "Range <span font='%d'>%.0f</span>%s".printf(
                    fh1,
                    Units.distance(NavStatus.cg.range),
                    Units.distance_units()
                                                           ));
            big_bearing.set_label("Bearing <span font='%d'>%d°</span>".printf(fh1,brg));
            big_hdr.set_label("Heading <span font='%d'>%d°</span>".printf(fh3,NavStatus.hdr));
            big_alt.set_label(
                "Alt <span font='%d'>%.1f</span>%s".printf(
                    fh3,
                    Units.distance(falt),
                    Units.distance_units() ));

            big_spd.set_label(
                "Speed <span font='%d'>%.1f</span>%s".printf(
                    fh1,
                    Units.speed(GPSInfo.spd),
                    Units.speed_units() ) );
            big_sats.set_label("Sats <span font='%d'>%d</span> %sfix".printf(fh1,GPSInfo.nsat,Units.fix(GPSInfo.fix)));
        }
    }
}

public class MapSeeder : GLib.Object
{
    private Gtk.Dialog dialog;
    private Gtk.SpinButton tile_minzoom;
    private Gtk.SpinButton tile_maxzoom;
    private Gtk.SpinButton tile_age;
    private Gtk.Label tile_stats;
    private Gtk.Button apply;
    private Gtk.Button stop;
    private int age  {get; set; default = 30;}
    private TileUtil ts;

    public MapSeeder(Gtk.Builder builder)
    {
        dialog = builder.get_object ("seeder_dialog") as Gtk.Dialog;
        tile_minzoom = builder.get_object ("tile_minzoom") as Gtk.SpinButton;
        tile_maxzoom = builder.get_object ("tile_maxzoom") as Gtk.SpinButton;
        tile_age = builder.get_object ("tile_age") as Gtk.SpinButton;
        tile_stats = builder.get_object ("tile_stats") as Gtk.Label;
        apply = builder.get_object ("tile_start") as Gtk.Button;
        stop = builder.get_object ("tile_stop") as Gtk.Button;

        dialog.destroy.connect (() => {
                reset();
            });

        ts = new TileUtil();
        tile_minzoom.adjustment.value_changed.connect (() =>  {
                int minv = (int)tile_minzoom.adjustment.value;
                int maxv = (int)tile_maxzoom.adjustment.value;
                if (minv > maxv)
                {
                    tile_minzoom.adjustment.value = maxv;
                }
                else
                {
                    ts.set_zooms(minv,maxv);
                    var nt = ts.build_table();
                    set_label(nt);
                }
            });
        tile_maxzoom.adjustment.value_changed.connect (() => {
                int minv = (int)tile_minzoom.adjustment.value;
                int maxv = (int)tile_maxzoom.adjustment.value;
                if (maxv < minv )
                {
                    tile_maxzoom.adjustment.value = minv;
                }
                else
                {
                    ts.set_zooms(minv,maxv);
                    var nt = ts.build_table( );
                    set_label(nt);
                }
            });

        apply.clicked.connect(() => {
                apply.sensitive = false;
                int days = (int)tile_age.adjustment.value;
                ts.set_delta(days);
                stop.set_label("Stop");
                ts.start_seeding();
            });
    }

    private void reset()
    {
        dialog.hide();
        ts.stop();
        ts = null;
    }


    private void set_label(TileUtil.TileStats s)
    {
        var lbl = "Tiles: %u / Skip: %u / DL: %u / Err: %u".printf(s.nt, s.skip, s.dlok, s.dlerr);
        tile_stats.set_label(lbl);
    }

    public void run_seeder(string mapid, int zval, Champlain.BoundingBox bbox)
    {
        var map_source_factory = Champlain.MapSourceFactory.dup_default();
        var sources =  map_source_factory.get_registered();
        string uri = null;
        int minz = 0;
        int maxz = 19;

        if(ts == null)
            ts = new TileUtil();

        foreach (Champlain.MapSourceDesc sr in sources)
        {
            if(mapid == sr.get_id())
            {
                uri = sr.get_uri_format ();
                minz = (int)sr.get_min_zoom_level();
                maxz = (int)sr.get_max_zoom_level();
                break;
            }
        }
        if(uri != null)
        {
            stop.set_label("Close");
            apply.sensitive = true;
            tile_maxzoom.adjustment.lower = minz;
            tile_maxzoom.adjustment.upper = maxz;
            tile_maxzoom.adjustment.value = zval;

            tile_minzoom.adjustment.lower = minz;
            tile_minzoom.adjustment.upper = maxz;
            tile_minzoom.adjustment.value = zval-4;
            tile_age.adjustment.value = age;

            ts.show_stats.connect((stats) => {
                    set_label(stats);
                });
            ts.tile_done.connect(() => {
                    apply.sensitive = true;
                    stop.set_label("Close");
                });
            ts.set_range(bbox.bottom, bbox.left, bbox.top, bbox.right);
            ts.set_misc(mapid, uri);
            ts.set_zooms(zval-4, zval);
            var nt = ts.build_table();
            set_label(nt);
            dialog.show_all();
            dialog.run();
            reset();
        }
    }

}



public class MapSourceDialog : GLib.Object
{
    private Gtk.Dialog dialog;
    private Gtk.Label map_name;
    private Gtk.Label map_id;
    private Gtk.Label map_minzoom;
    private Gtk.Label map_maxzoom;
    private Gtk.Label map_uri;

    public MapSourceDialog(Gtk.Builder builder)
    {
        dialog = builder.get_object ("map_source_dialog") as Gtk.Dialog;
        map_name = builder.get_object ("map_name") as Gtk.Label;
        map_id = builder.get_object ("map_id") as Gtk.Label;
        map_uri = builder.get_object ("map_uri") as Gtk.Label;
        map_minzoom = builder.get_object ("map_minzoom") as Gtk.Label;
        map_maxzoom = builder.get_object ("map_maxzoom") as Gtk.Label;
    }

    public void show_source(string name, string id, string uri, uint minzoom, uint maxzoom)
    {
        map_name.set_label(name);
        map_id.set_label(id);
        map_uri.set_label(uri);
        map_minzoom.set_label(minzoom.to_string());
        map_maxzoom.set_label(maxzoom.to_string());
        dialog.show_all();
        dialog.run();
        dialog.hide();
    }
}

public class DeltaDialog : GLib.Object
{
    private Gtk.Dialog dialog;
    private Gtk.Entry dlt_entry1;
    private Gtk.Entry dlt_entry2;
    private Gtk.Entry dlt_entry3;

    public DeltaDialog(Gtk.Builder builder)
    {
        dialog = builder.get_object ("delta-dialog") as Gtk.Dialog;
        dlt_entry1 = builder.get_object ("dlt_entry1") as Gtk.Entry;
        dlt_entry2 = builder.get_object ("dlt_entry2") as Gtk.Entry;
        dlt_entry3 = builder.get_object ("dlt_entry3") as Gtk.Entry;
    }

    public bool get_deltas(out double dlat, out double dlon, out int dalt)
    {
        var res = false;
        dialog.show_all();
        dlat = dlon = 0.0;
        dalt = 0;
        var id = dialog.run();
        switch(id)
        {
            case 1001:
                dlat = get_locale_double(dlt_entry1.get_text());
                dlon = get_locale_double(dlt_entry2.get_text());
                dalt = (int)InputParser.get_scaled_int(dlt_entry3.get_text());
                res = true;
                break;

            case 1002:
                break;
        }
        dialog.hide();
        return res;
    }

}

public class SetPosDialog : GLib.Object
{
    private Gtk.Dialog dialog;
    private Gtk.Entry lat_entry;
    private Gtk.Entry lon_entry;

    public SetPosDialog(Gtk.Builder builder)
    {
        dialog = builder.get_object ("gotodialog") as Gtk.Dialog;
        lat_entry = builder.get_object ("golat") as Gtk.Entry;
        lon_entry = builder.get_object ("golon") as Gtk.Entry;
    }

    public bool get_position(out double glat, out double glon)
    {
        var res = false;
        dialog.show_all();
        glat = glon = 0.0;
        var id = dialog.run();
        switch(id)
        {
            case 1001:
                glat = InputParser.get_latitude(lat_entry.get_text());
                glon = InputParser.get_longitude(lon_entry.get_text());
                res = true;
                break;

            case 1002:
                break;
        }
        dialog.hide();
        return res;
    }

}

public class SwitchDialog : GLib.Object
{
    private Gtk.Dialog dialog;
    public SwitchDialog(Gtk.Builder builder)
    {
        dialog = builder.get_object ("switch-dialogue") as Gtk.Dialog;
    }
    public void run()
    {
        dialog.show_all();
        var id = dialog.run();
        dialog.hide();
        if(id == 1002)
            Posix.exit(255);
    }
}


public class PrefsDialog : GLib.Object
{
    private Gtk.Dialog dialog;
    private Gtk.Entry[]ents = {};
    private Gtk.RadioButton[] buttons={};

    private uint pspeed;
    private uint pdist;
    private bool pdms;

    private enum Buttons
    {
        DDD=0,
        DMS,

        METRE,
        FEET,
        YARDS,

        MSEC,
        KPH,
        MPH,
        KNOTS
    }

    private void toggled (Gtk.ToggleButton button) {
        if(button.get_active())
        {
            switch(button.label)
            {
                case "DDD.dddddd":
                    pdms = false;
                    break;
                case "DDD:MM:SS.s":
                    pdms = true;
                    break;
                case "Metres":
                    pdist = 0;
                    break;
                case "Feet":
                    pdist = 1;
                    break;
                case "Yards":
                    pdist = 2;
                    break;
                case "m/s":
                    pspeed = 0;
                    break;
                case "kph":
                    pspeed = 1;
                    break;
                case "mph":
                    pspeed = 2;
                    break;
                case "knots":
                    pspeed = 3;
                    break;
                default:
                    stderr.printf("Invalid label %s\n", button.label);
                    break;
            }
        }
    }

    public PrefsDialog(Gtk.Builder builder)
    {
        dialog = builder.get_object ("prefs-dialog") as Gtk.Dialog;
        for (int i = 1; i < 10; i++)
        {
            var id = "prefentry%d".printf(i);
            var e = builder.get_object (id) as Gtk.Entry;
            ents += e;
        }

        Gtk.RadioButton button;
        string [] pnames = {
            "uprefs-ddd", "uprefs-dms",
            "uprefs-metre", "uprefs-feet", "uprefs-yards",
            "uprefs-msec", "uprefs-kph", "uprefs-mph", "uprefs-knots"
        };

        foreach(var s in pnames)
        {
            button = builder.get_object (s) as Gtk.RadioButton;
            button.toggled.connect (toggled);
            buttons += button;
        }

        dialog.set_default_size (640, 320);

        var content = dialog.get_content_area () as Gtk.Box;
        Gtk.Notebook notebook = new Gtk.Notebook ();
        content.pack_start (notebook, false, true, 0);
        content.spacing = 4;

        var gprefs = builder.get_object ("gprefs") as Gtk.Box;
        var uprefs = builder.get_object ("uprefs") as Gtk.Box;

        notebook.append_page(gprefs,new Gtk.Label("General"));
        notebook.append_page(uprefs,new Gtk.Label("Units"));
    }

    public void run_prefs(ref MWPSettings conf)
    {
        StringBuilder sb = new StringBuilder ();
        if(conf.devices != null)
        {
            var delimiter = ", ";
            foreach (string s in conf.devices)
            {
                sb.append(s);
                sb.append(delimiter);
            }
            sb.truncate (sb.len - delimiter.length);
            ents[0].set_text(sb.str);
        }

        string dp;
        dp = PosFormat.lat(conf.latitude, conf.dms);
        ents[1].set_text(dp);
        dp = PosFormat.lon(conf.longitude, conf.dms);
        ents[2].set_text(dp);
        ents[3].set_text("%u".printf(conf.loiter));

        var al = Units.distance((double)conf.altitude);
        ents[4].set_text("%.0f".printf(al));
        al = Units.speed(conf.nav_speed);
        ents[5].set_text("%.2f".printf(al));
        ents[6].set_text(conf.defmap);
        ents[7].set_text("%u".printf(conf.zoom));
        ents[8].set_text("%u".printf(conf.speakint));

        if(conf.dms)
            buttons[Buttons.DMS].set_active(true);
        else
            buttons[Buttons.DDD].set_active(true);

        buttons[conf.p_distance + Buttons.METRE].set_active(true);
        buttons[conf.p_speed + Buttons.MSEC].set_active(true);

        dialog.show_all ();
        var id = dialog.run();
        switch(id)
        {
            case 1001:
                var str = ents[0].get_text();
                double d;
                uint u;
                if(sb.str != str)
                {
                    var strs = str.split(",");
                    for(int i=0; i<strs.length;i++)
                    {
                        strs[i] = strs[i].strip();
                    }
                    conf.settings.set_strv( "device-names", strs);
                }
                str = ents[1].get_text();
                d=InputParser.get_latitude(str);
                if(Math.fabs(conf.latitude - d) > 1e-5)
                {
                    conf.settings.set_double("default-latitude", d);
                }
                str = ents[2].get_text();
                d=InputParser.get_longitude(str);
                if(Math.fabs(conf.longitude - d) > 1e-5)
                if(conf.longitude != d)
                {
                    conf.settings.set_double("default-longitude", d);
                }
                str = ents[3].get_text();
                u=int.parse(str);
                if(conf.loiter != u)
                {
                    conf.settings.set_uint("default-loiter", u);
                }
                str = ents[4].get_text();
                u = (uint)InputParser.get_scaled_int(str);
                if(conf.altitude != u)
                {
                    conf.settings.set_uint("default-altitude", u);
                }
                str = ents[5].get_text();
                d = InputParser.get_scaled_real(str, "s");
                if(Math.fabs(conf.nav_speed -d) > 0.1)
                {
                    conf.settings.set_double("default-nav-speed", d);
                }
                str = ents[6].get_text();
                if(conf.defmap !=str)
                {
                    conf.settings.set_string ("default-map", str);
                }
                str = ents[7].get_text();
                u=int.parse(str);
                if(conf.zoom != u)
                {
                    conf.settings.set_uint("default-zoom", u);
                }

                if(conf.dms != pdms)
                {
                    conf.settings.set_boolean("display-dms", pdms);
                }

                if(conf.p_distance != pdist)
                {
                    conf.settings.set_uint("display-distance", pdist);
                }

                if(conf.p_speed != pspeed)
                {
                    conf.settings.set_uint("display-speed", pspeed);
                }

                str = ents[8].get_text();
                u=int.parse(str);
                if(u > 0 && conf.speakint < 15)
                {
                    u = 15;
                    ents[8].set_text("%u".printf(u));
                }
                if(conf.speakint != u)
                {
                    conf.settings.set_uint("speak-interval",u);

                }
                break;
            case 1002:
                break;
        }
        dialog.hide();
    }
}

public class ShapeDialog : GLib.Object
{
    public struct ShapePoint
    {
        public double lat;
        public double lon;
        public double bearing;
        public int no;
    }

    private ShapePoint[] points;
    private Gtk.Dialog dialog;
    private Gtk.SpinButton spin1;
    private Gtk.SpinButton spin2;
    private Gtk.SpinButton spin3;
    private Gtk.ComboBoxText combo;

    public ShapeDialog(Gtk.Builder builder)
    {
        dialog = builder.get_object ("shape-dialog") as Gtk.Dialog;
        spin1  = builder.get_object ("shp_spinbutton1") as Gtk.SpinButton;
        spin2  = builder.get_object ("shp_spinbutton2") as Gtk.SpinButton;
        spin3  = builder.get_object ("shp_spinbutton3") as Gtk.SpinButton;
        combo  = builder.get_object ("shp-combo") as Gtk.ComboBoxText;
        spin2.adjustment.value = 0;
    }

    public ShapePoint[] get_points(double clat, double clon)
    {
        ShapePoint[] p = {};
        dialog.show_all();
        var id = dialog.run();
        switch(id)
        {
            case 1001:

                var npts = (int)spin1.adjustment.value;
                var radius = spin2.adjustment.value;
                var start = spin3.adjustment.value;
                var dtext = combo.get_active_id();
                int dirn = 1;

                if(dtext != null)
                    dirn = int.parse(dtext);

                radius = InputParser.get_scaled_real(radius.to_string());
                if(radius > 0)
                {
                    radius /= 1852.0;
                    mkshape(clat, clon, radius, npts, start, dirn);
                    p = points;
                }

                break;
            case 1002:
                break;
        }
        dialog.hide();
        return p;
    }

    private void mkshape(double clat, double clon,double radius,
                         int npts=6, double start = 0, int dirn=1)
    {
        double ang = start;
        double dint  = dirn*(360.0/npts);
        points= {};
        for(int i =0; i <= npts; i++)
        {
            double lat,lon;
            Geo.posit(clat,clon,ang,radius,out lat, out lon);
            var p = ShapePoint() {no = i, lat=lat, lon=lon, bearing = ang};
            points += p;
            ang = (ang + dint) % 360.0;
            if (ang < 0.0)
                ang += 360;
        }
    }
}

public class RadioStatus : GLib.Object
{
    private Gtk.Label rxerr_label;
    private Gtk.Label fixerr_label;
    private Gtk.Label locrssi_label;
    private Gtk.Label remrssi_label;
    private Gtk.Label txbuf_label;
    private Gtk.Label noise_label;
    private Gtk.Label remnoise_label;
    public Gtk.Grid grid {get; private set;}
    private MSP_RADIO r;

    public RadioStatus(Gtk.Builder builder)
    {
        grid = builder.get_object ("grid4") as Gtk.Grid;
        rxerr_label = builder.get_object ("rxerrlab") as Gtk.Label;
        fixerr_label = builder.get_object ("fixerrlab") as Gtk.Label;
        locrssi_label = builder.get_object ("locrssilab") as Gtk.Label;
        remrssi_label = builder.get_object ("remrssilab") as Gtk.Label;
        txbuf_label = builder.get_object ("txbuflab") as Gtk.Label;
        noise_label = builder.get_object ("noiselab") as Gtk.Label;
        remnoise_label = builder.get_object ("remnoiselab") as Gtk.Label;
        grid.show_all();
    }


    public void update_ltm(LTM_SFRAME s,bool visible)
    {
        if(visible)
            remrssi_label.set_label(s.rssi.to_string());
    }

    public void update(MSP_RADIO _r, bool visible)
    {
        r = _r;

        if(visible)
        {
            rxerr_label.set_label(r.rxerrors.to_string());
            fixerr_label.set_label(r.fixed_errors.to_string());
            locrssi_label.set_label(r.localrssi.to_string());
            remrssi_label.set_label(r.remrssi.to_string());
            txbuf_label.set_label(r.txbuf.to_string());
            noise_label.set_label(r.noise.to_string());
            remnoise_label.set_label(r.remnoise.to_string());
        }

        if (Logger.is_logging)
        {
            Logger.radio(r);
        }
    }
}

public class NavStatus : GLib.Object
{
    private Gtk.Label gps_mode_label;
    private Gtk.Label nav_state_label;
    private Gtk.Label nav_action_label;
    private Gtk.Label nav_wp_label;
    private Gtk.Label nav_err_label;
    private Gtk.Label nav_tgt_label;
    private Gtk.Label nav_comp_gps_label;
    private Gtk.Label nav_altitude_label;
    private Gtk.Label nav_attitude_label;
    private bool enabled = false;
    public Gtk.Grid grid {get; private set;}
    private  Gtk.Label voltlabel;
    public Gtk.Box voltbox{get; private set;}
    private Gdk.RGBA[] colors;
    private bool vinit = false;
    private bool mt_voice = false;
    private AudioThread mt;
    private bool have_cg = false;
    private bool have_hdr = false;

    public static MSP_NAV_STATUS n {get; private set;}
    public static MSP_ATTITUDE atti {get; private set;}
    public static MSP_ALTITUDE alti {get; private set;}
    public static MSP_COMP_GPS cg {get; private set;}
    public static float volts {get; private set;}
    public static uint8 numsat {get; private set;}
    public static int16 hdr {get; private set;}
    public static bool modsat;

    public static uint8 xfmode {get; private set;}
    public static int mins {get; private set;}
    public static bool recip {get; private set;}
    public static string fmode;
    private static string ls_state = null;
    private static string ls_action = null;
    private static string ns_action = null;
    private static string ns_state = null;

    private int _vn;
    private int _aw;
    private int _ah;
    private int _fs;

    public enum SPK  {
        Volts = 1,
        GPS = 2,
        BARO = 4,
        ELEV = 8
    }

    public NavStatus(Gtk.Builder builder)
    {
        xfmode = 255;
        numsat = 0;
        modsat = false;

        grid = builder.get_object ("grid3") as Gtk.Grid;
        gps_mode_label = builder.get_object ("gps_mode_lab") as Gtk.Label;
        nav_state_label = builder.get_object ("nav_status_label") as Gtk.Label;
        nav_action_label = builder.get_object ("nav_action_label") as Gtk.Label;
        nav_wp_label = builder.get_object ("nav_wp_label") as Gtk.Label;
        nav_err_label = builder.get_object ("nav_error_label") as Gtk.Label;
        nav_tgt_label = builder.get_object ("nav_bearing_label") as Gtk.Label;

        nav_comp_gps_label = builder.get_object ("comp_gps_label") as Gtk.Label;
        nav_altitude_label = builder.get_object ("altitude_label") as Gtk.Label;
        nav_attitude_label = builder.get_object ("attitude_label") as Gtk.Label;
        enabled = true;

        voltlabel = new Gtk.Label("");
        voltbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
        voltlabel.set_use_markup (true);
        voltbox.pack_start (voltlabel, true, true, 1);
        colors = new Gdk.RGBA[5];
        colors[0].parse("green");
        colors[1].parse("yellow");
        colors[2].parse("orange");
        colors[3].parse("red");
        colors[4].parse("white");
        volt_update("n/a",4, 0f,true);
        grid.show_all();
    }


    public void update_ltm_a(LTM_AFRAME a, bool visible)
    {
        if(enabled || Logger.is_logging)
        {
            hdr = a.heading;
            if(hdr < 0)
                hdr += 360;
            have_hdr = true;
            if(visible)
            {
               var str = "%d° / %d° / %d°".printf(a.pitch, a.roll, hdr);
                nav_attitude_label.set_label(str);
            }
            if(Logger.is_logging)
            {
                Logger.attitude(a.pitch,a.roll,hdr);
            }
        }
    }

    public void update(MSP_NAV_STATUS _n, bool visible, uint8 flag = 0)
    {
        if(mt_voice == true)
        {
            var xnmode = n.nav_mode;
            var xnerr = n.nav_error;
            var xnwp = n.wp_number;

            n = _n;

            if(_n.nav_mode != 0 &&
               _n.nav_error != 0 &&
               _n.nav_error != 4 &&
               _n.nav_error != 5 &&
               _n.nav_error != 6 &&
               _n.nav_error != 7 &&
               _n.nav_error != 8 &&
               _n.nav_error != xnerr)
            {
                mt.message(AudioThread.Vox.NAV_ERR,true);
            }

            if((_n.nav_mode != xnmode) || (_n.nav_mode !=0 && _n.wp_number != xnwp))
            {
                mt.message(AudioThread.Vox.NAV_STATUS,true);
            }
        }

        if(visible)
        {
            var gstr = MSP.gps_mode(n.gps_mode);
            var n_action = n.action;
            var n_wpno = (n.nav_mode == 0) ? 0 : n.wp_number;
            var estr = MSP.nav_error(n.nav_error);
            var tbrg = n.target_bearing;
            ns_state = MSP.nav_state(n.nav_mode);
            ns_action = MSP.get_wpname((MSP.Action)n_action);

            gps_mode_label.set_label(gstr);
            set_nav_state_act();
            nav_wp_label.set_label("%d".printf(n_wpno));
            nav_err_label.set_label(estr);
            if(flag == 0)
                nav_tgt_label.set_label("%d".printf(tbrg));
            else
                nav_tgt_label.set_label("[%x]".printf(tbrg));
        }

        if (Logger.is_logging)
        {
            Logger.status(n);
        }
    }

    private void set_nav_state_act()
    {
        StringBuilder sb = new StringBuilder ();
        if (ns_state != null)
        {
            sb.append(ns_state);
            sb.append(" ");
        }
        if (ls_state != null)
            sb.append(ls_state);
        nav_state_label.set_label(sb.str);

        sb.assign("");
        if (ns_action != null)
        {
            sb.append(ns_action);
            sb.append(" ");
        }
        if (ls_action != null)
            sb.append(ls_action);

        nav_action_label.set_label(sb.str);
    }

    public void update_ltm_s(LTM_SFRAME s, bool visible)
    {
        if(enabled || Logger.is_logging)
        {
            uint8 armed = (s.flags & 1);
            uint8 failsafe = ((s.flags & 2) >> 1);
            uint8 fmode = (s.flags >> 2);

            ls_state = MSP.ltm_mode(fmode);
            ls_action = "%s %s".printf(((armed == 1) ? "armed" : "disarmed"),
                                     ((failsafe == 1) ? "failsafe" : ""));
            if(visible)
            {
                set_nav_state_act();
            }
            if(xfmode != fmode)
            {
                xfmode = fmode;
                    // only speak modes that are in N-Frame
                if(mt_voice && xfmode > 0 && xfmode < 5)
                {
                    mt.message(AudioThread.Vox.LTM_MODE,true);
                }
            }

            if (Logger.is_logging)
            {
                var b = new StringBuilder ();
                b.append(ls_action.strip());
                b.append(" ");
                b.append(ls_state);
                Logger.ltm_sframe(s, b.str);
            }
        }
    }




    public void set_attitude(MSP_ATTITUDE _atti,bool visible)
    {
        atti = _atti;
        if(enabled || Logger.is_logging)
        {
            double dax;
            double day;
            dax = (double)(atti.angx)/10.0;
            day = (double)(atti.angy)/10.0;
            hdr = atti.heading;
            if(hdr < 0)
                hdr += 360;

            have_hdr = true;
            if(visible)
            {
                var str = "%.1f° / %.1f° / %d°".printf(dax, day, hdr);
                nav_attitude_label.set_label(str);
            }
            if(Logger.is_logging)
            {
                Logger.attitude(dax,day,hdr);
            }
        }
    }

    public void set_altitude(MSP_ALTITUDE _alti, bool visible)
    {
        alti = _alti;
        if(enabled || Logger.is_logging)
        {
            double vario = alti.vario/10.0;
            double estalt = alti.estalt/100.0;
            if(visible)
            {
                var str = "%.1f%s / %.1f%s".printf(
                    Units.distance(estalt),
                    Units.distance_units(),
                    Units.va_speed(vario),
                    Units.va_speed_units());
                nav_altitude_label.set_label(str);
            }
            if(Logger.is_logging)
            {
                Logger.altitude(estalt,vario);
            }
        }
    }

    public void set_mav_attitude(Mav.MAVLINK_ATTITUDE m, bool visible)
    {
        double dax;
        double day;
        dax = m.roll * 57.29578;
        day = m.pitch * 57.29578;
        hdr = (int16) (m.yaw * 57.29578);

        if(hdr < 0)
            hdr += 360;

        have_hdr = true;
        if(visible)
        {
            var str = "%.1f° / %.1f° / %d°".printf(dax, day, hdr);
            nav_attitude_label.set_label(str);
        }
        if(Logger.is_logging)
        {
            Logger.mav_attitude(m);
        }
    }

    public void  set_mav_altitude(Mav.MAVLINK_VFR_HUD m, bool visible)
    {
        alti = {(int32)(m.alt * 100), (int16)(m.climb*10)};
        if(visible)
        {
            var str = "%.1f%s / %.1f%s".printf(
                Units.distance(m.alt),
                Units.distance_units(),
                Units.va_speed(m.climb),
                Units.va_speed_units());
            nav_altitude_label.set_label(str);
        }
        if(Logger.is_logging)
        {
            Logger.mav_vfr_hud(m);
        }
    }

    public void comp_gps(MSP_COMP_GPS _cg, bool visible)
    {
        cg = _cg;
        have_cg = true;
        if(enabled || Logger.is_logging)
        {
            var brg = cg.direction;
            if(brg < 0)
                brg += 360;

            if(visible)
            {
                var str = "%.0f%s / %d° / %s".printf(
                    Units.distance(cg.range),
                    Units.distance_units(),
                    brg,
                    (cg.update == 0) ? "false" : "true");
                nav_comp_gps_label.set_label(str);
            }
            if(Logger.is_logging)
            {
                Logger.comp_gps(brg,cg.range,cg.update);
            }
        }
    }

    public void volt_update(string s, int n, float v, bool visible)
    {
        volts = v;
        if(visible)
        {
            Gtk.Allocation a;
            if(n != _vn)
            {
                voltlabel.override_background_color(Gtk.StateFlags.NORMAL, colors[n]);
                _vn = n;
            }
            voltlabel.get_allocation(out a);
            if (a.width != _aw || a.height != _ah)
            {
                _aw = a.width;
                _ah = a.height;
                var fh1 = a.width/4;
                var fh2 = a.height / 2;
                var fs = (fh1 < fh2) ? fh1 : fh2;
                _fs = fs;
            }
            voltlabel.set_label("<span font='%d'>%s</span>".printf(_fs,s));
        }
    }

    public void update_fmode(string _fmode)
    {
        fmode = _fmode;
        if(mt_voice)
        {
            mt.message(AudioThread.Vox.FMODE,true);
        }
    }

    public void update_duration(int _mins)
    {
        mins = _mins;
        if(mt_voice)
        {
            mt.message(AudioThread.Vox.DURATION);
        }
    }

    public void sats(uint8 nsats, bool urgent=false)
    {
        numsat = nsats;
        modsat = true;
        if(urgent)
        {
            mt.message(AudioThread.Vox.MODSAT,true);
            modsat = false;
        }
    }

    public void announce(uint8 mask, bool _recip)
    {
        recip = _recip;
        if(((mask & SPK.GPS) == SPK.GPS) && have_cg)
        {
            mt.message(AudioThread.Vox.RANGE_BRG);
        }
        if((mask & SPK.ELEV) == SPK.ELEV)
        {
            mt.message(AudioThread.Vox.ELEVATION);
        }
        else if((mask & SPK.BARO) == SPK.BARO)
        {
            mt.message(AudioThread.Vox.BARO);
        }

        if(have_hdr)
        {
            mt.message(AudioThread.Vox.HEADING);
        }

        if((mask & SPK.Volts) == SPK.Volts && volts > 0.0)
        {
            mt.message(AudioThread.Vox.VOLTAGE);
        }

        if(modsat)
        {
            mt.message(AudioThread.Vox.MODSAT,true);
        }
    }

    public void cg_on()
    {
        have_cg = true;
    }

    public void reset_states()
    {
        ls_state = null;
        ls_action = null;
        ns_state = null;
        ns_action = null;
    }

    public void reset()
    {
        have_cg = false;
        have_hdr = false;
        volts = 0;
        reset_states();
    }

    public void logspeak_init (string? voice)
    {
        if(vinit == false)
        {
            vinit = true;
            if(voice == null)
                voice = "default";
            espeak_init(voice);
        }

        if (mt != null)
        {
            logspeak_close();
        }
//        stdout.printf("Start audio\n");
        mt = new AudioThread();
        mt.start();
        mt_voice=true;
    }

    public void logspeak_close()
    {
//        MWPLog.message("Stop audio\n");
        mt_voice=false;
        mt.clear();
        mt.message(AudioThread.Vox.DONE);
        mt.thread.join ();
        mt = null;
    }
}

public class AudioThread : Object {
    public enum Vox
    {
        DONE=1,
        NAV_ERR,
        NAV_STATUS,
        DURATION,
        FMODE,
        RANGE_BRG,
        ELEVATION,
        BARO,
        HEADING,
        VOLTAGE,
        MODSAT,
        LTM_MODE
    }

    private AsyncQueue<Vox> msgs;
    public Thread<int> thread {private set; get;}

    public AudioThread () {
        msgs = new AsyncQueue<Vox> ();
    }

    private string str_zero(string str)
    {
        if(str[-3:-1] == ".0")
        {
            return str[0:-2];
        }
        else
        {
            return str;
        }
    }

    public void message(Vox c, bool urgent=false)
    {
        if (msgs.length() > 8)
        {
            clear();
            MWPLog.message("cleared voice queue\n");
        }
        if(!urgent)
            msgs.push(c);
        else
        {
#if NOPUSHFRONT
        // less efficient work around for Ubuntu (again)
            msgs.push_sorted(c, () => { return 1; });
#else
            msgs.push_front(c);
#endif
        }
    }

    public void clear()
    {
        while (msgs.try_pop() != (Vox)null)
            ;
    }

    public void start()
    {
        thread = new Thread<int> ("mwp audio", () => {
                Vox c;
                while((c = msgs.pop()) != Vox.DONE)
                {
                    string s=null;
                    switch(c)
                    {
                        case Vox.NAV_ERR:
                            s = MSP.nav_error(NavStatus.n.nav_error);
                            break;
                        case Vox.NAV_STATUS:
                            switch(NavStatus.n.nav_mode)
                            {
                                case 0:
                                    s = "Manual mode.";
                                    break;
                                case 1:
                                    s = "Return to home initiated.";
                                    break;
                                case 2:
                                    s = "Navigating to home position.";
                                    break;
                                case 3:
                                    s = "Switch to infinite position hold.";
                                    break;
                                case 4:
                                    s = "Start timed position hold.";
                                    break;
                                case 5:
                                    s = "Navigating to waypoint %d.".printf(NavStatus.n.wp_number);
                                    break;
                                case 7:
                                    s = "Starting jump for %d".printf(NavStatus.n.wp_number);
                                    break;
                                case 8:
                                    s = "Starting to land.";
                                    break;
                                case 9:
                                    s = "Landing in progress.";
                                    break;
                                case 10:
                                    s = "Landed. Please disarm.";
                                    break;
                            }
                            break;
                        case Vox.DURATION:
                            var ms = (NavStatus.mins > 1) ? "minutes" : "minute";
                            s = "%d %s".printf(NavStatus.mins, ms);
                            break;
                        case Vox.FMODE:
                            s = "%s mode".printf(NavStatus.fmode);
                            break;
                        case Vox.RANGE_BRG:
                            var brg = NavStatus.cg.direction;
                            if(brg < 0)
                                brg += 360;
                            if(NavStatus.recip)
                                brg = ((brg + 180) % 360);
                            s = "Range %.0f, bearing %d.".printf(
                                Units.distance(NavStatus.cg.range),
                                brg);
                            break;
                        case Vox.ELEVATION:
                            s = "Elevation %.0f.".printf(Units.distance(GPSInfo.elev));
                            s = str_zero(s);
                            break;
                        case Vox.BARO:
                            double estalt = (double)NavStatus.alti.estalt/100.0;
                            s  = "Altitude %.1f.".printf(Units.distance(estalt));
                            s = str_zero(s);
                            break;
                        case Vox.HEADING:
                            s = "Heading %d.".printf(NavStatus.hdr);
                            break;
                        case Vox.VOLTAGE:
                            s = "Voltage %.1f.".printf( NavStatus.volts);
                            s = str_zero(s);
                            break;
                        case Vox.MODSAT:
                            string ss = "";
                            if(NavStatus.numsat != 1)
                                ss = "s";
                            s = "%d satellite%s.".printf(NavStatus.numsat,ss);
                            break;
                        case Vox.LTM_MODE:
                            s = MSP.ltm_mode(NavStatus.xfmode);
                            break;
                        default:
                            break;
                    }
                    if(s != null)
                    {
//                        MWPLog.message("say %s %s\n", c.to_string(), s);
                        espeak_say(s);
                    }
                }
                return 0;
            });
    }
}

public class NavConfig : GLib.Object
{
    private Gtk.Window window;
    private bool visible;
    private Gtk.CheckButton nvcb1_01;
    private Gtk.CheckButton nvcb1_02;
    private Gtk.CheckButton nvcb1_03;
    private Gtk.CheckButton nvcb1_04;
    private Gtk.CheckButton nvcb1_05;
    private Gtk.CheckButton nvcb1_06;
    private Gtk.CheckButton nvcb1_07;
    private Gtk.CheckButton nvcb1_08;
    private Gtk.CheckButton nvcb2_01;
    private Gtk.CheckButton nvcb2_02;
    private Gtk.Entry wp_radius;
    private Gtk.Entry safe_wp_dist;
    private Gtk.Entry nav_max_alt;
    private Gtk.Entry nav_speed_max;
    private Gtk.Entry nav_speed_min;
    private Gtk.Entry crosstrack_gain;
    private Gtk.Entry nav_bank_max;
    private Gtk.Entry rth_altitude;
    private Gtk.Entry land_speed;
    private Gtk.Entry fence;
    private Gtk.Entry max_wp_no;
    private uint8 _xtrack;
    private uint8 _maxwp;
    private MWPlanner _mwp;

    public NavConfig (Gtk.Window parent, Gtk.Builder builder, MWPlanner m)
    {
        _mwp = m;
        window = builder.get_object ("nc_window") as Gtk.Window;
        var button = builder.get_object ("nc_close") as Gtk.Button;
        button.clicked.connect(() => {
                window.hide();
            });

        var apply = builder.get_object ("nc_apply") as Gtk.Button;
        apply.clicked.connect(() => {
                MSP_NAV_CONFIG ncu = MSP_NAV_CONFIG();
                if (nvcb1_01.active)
                    ncu.flag1 |= 0x01;
                if (nvcb1_02.active)
                    ncu.flag1 |= 0x02;
                    // Logic inverted
                if (nvcb1_03.active == false)
                    ncu.flag1 |= 0x04;
                if (nvcb1_04.active)
                    ncu.flag1 |= 0x08;
                if (nvcb1_05.active)
                    ncu.flag1 |= 0x10;
                if (nvcb1_06.active)
                    ncu.flag1 |= 0x20;
                if (nvcb1_07.active)
                    ncu.flag1 |= 0x40;
                if (nvcb1_08.active)
                    ncu.flag1 |= 0x80;

                if (nvcb2_01.active)
                    ncu.flag2 |= 0x01;
                if (nvcb2_02.active)
                    ncu.flag2 |= 0x02;

                uint16 u16;
                u16 = (uint16)int.parse(wp_radius.get_text());
                ncu.wp_radius = u16;
                u16 = (uint16) int.parse(safe_wp_dist.get_text());
                ncu.safe_wp_distance = u16;
                u16 = (uint16)int.parse(nav_max_alt.get_text());
                ncu.nav_max_altitude = u16;
                u16 = (uint16)int.parse(nav_speed_max.get_text());
                ncu.nav_speed_max = u16;
                u16 = (uint16)int.parse(nav_speed_min.get_text());
                ncu.nav_speed_min = u16;

                string s = nav_bank_max.get_text();
                u16 = (uint16)(get_locale_double(s)*100);
                ncu.nav_bank_max = u16;
                u16 = (uint16)int.parse(rth_altitude.get_text());
                ncu.rth_altitude = u16;
                ncu.land_speed = (uint8)int.parse(land_speed.get_text());
                u16 = (uint16)int.parse(fence.get_text());
                ncu.fence = u16;
                ncu.crosstrack_gain = _xtrack;
                ncu.max_wp_number = _maxwp;
                _mwp.update_config(ncu);
            });


       nvcb1_01 = builder.get_object ("nvcb1_01") as Gtk.CheckButton;
       nvcb1_02 = builder.get_object ("nvcb1_02") as Gtk.CheckButton;
       nvcb1_03 = builder.get_object ("nvcb1_03") as Gtk.CheckButton;
       nvcb1_04 = builder.get_object ("nvcb1_04") as Gtk.CheckButton;
       nvcb1_05 = builder.get_object ("nvcb1_05") as Gtk.CheckButton;
       nvcb1_06 = builder.get_object ("nvcb1_06") as Gtk.CheckButton;
       nvcb1_07 = builder.get_object ("nvcb1_07") as Gtk.CheckButton;
       nvcb1_08 = builder.get_object ("nvcb1_08") as Gtk.CheckButton;
       nvcb2_01 = builder.get_object ("nvcb2_01") as Gtk.CheckButton;
       nvcb2_02 = builder.get_object ("nvcb2_02") as Gtk.CheckButton;
       wp_radius = builder.get_object ("wp_radius") as Gtk.Entry;
       safe_wp_dist = builder.get_object ("safe_wp_dist") as Gtk.Entry;
       nav_max_alt = builder.get_object ("nav_max_alt") as Gtk.Entry;
       nav_speed_max = builder.get_object ("nav_speed_max") as Gtk.Entry;
       nav_speed_min = builder.get_object ("nav_speed_min") as Gtk.Entry;
       crosstrack_gain = builder.get_object ("crosstrack_gain") as Gtk.Entry;
       nav_bank_max = builder.get_object ("nav_bank_max") as Gtk.Entry;
       rth_altitude  = builder.get_object ("rth_altitude") as Gtk.Entry;
       land_speed = builder.get_object ("land_speed") as Gtk.Entry;
       fence = builder.get_object ("fence") as Gtk.Entry;
       max_wp_no = builder.get_object ("max_wp_no") as Gtk.Entry;

        window.set_transient_for(parent);
        window.destroy.connect (() => {
                window.hide();
                visible = false;
            });
    }

    public void update(MSP_NAV_CONFIG nc)
    {
        nvcb1_01.set_active ((nc.flag1 & 0x01) == 0x01);
        nvcb1_02.set_active ((nc.flag1 & 0x02) == 0x02);
            // Logic deliberately inverted
        nvcb1_03.set_active ((nc.flag1 & 0x04) != 0x04);
        nvcb1_04.set_active ((nc.flag1 & 0x08) == 0x08);
        nvcb1_05.set_active ((nc.flag1 & 0x10) == 0x10);
        nvcb1_06.set_active ((nc.flag1 & 0x20) == 0x20);
        nvcb1_07.set_active ((nc.flag1 & 0x40) == 0x40);
        nvcb1_08.set_active ((nc.flag1 & 0x80) == 0x80);
        nvcb2_01.set_active ((nc.flag2 & 0x01) == 0x01);
        nvcb2_02.set_active ((nc.flag2 & 0x02) == 0x02);

        wp_radius.set_text(nc.wp_radius.to_string());
        safe_wp_dist.set_text(nc.safe_wp_distance.to_string());
        nav_max_alt.set_text(nc.nav_max_altitude.to_string());
        nav_speed_max.set_text(nc.nav_speed_max.to_string());
        nav_speed_min.set_text(nc.nav_speed_min.to_string());
        crosstrack_gain.set_text("%.2f".printf((double)nc.crosstrack_gain/100.0));
        nav_bank_max.set_text("%.2f".printf((double)nc.nav_bank_max/100.0));
        rth_altitude.set_text(nc.rth_altitude.to_string());
        land_speed.set_text(nc.land_speed.to_string());
        fence.set_text(nc.fence.to_string());
        max_wp_no.set_text(nc.max_wp_number.to_string());
        _xtrack = nc.crosstrack_gain;
        _maxwp = nc.max_wp_number;
    }

    public void hide()
    {
        window.hide();
        visible = false;
    }

    public void show()
    {
        visible = true;
        window.show_all();
    }
}

public class GPSInfo : GLib.Object
{
    private Gtk.Label nsat_lab;
    private Gtk.Label lat_lab;
    private Gtk.Label lon_lab;
    private Gtk.Label alt_lab;
    private Gtk.Label dirn_lab;
    private Gtk.Label speed_lab;
    private double _dlon = 0;
    private double _dlat = 0;

    public static double lat {get; private set;}
    public static double lon {get; private set;}
    public static double cse {get; private set;}
    public static double spd {get; private set;}
    public static int nsat {get; private set;}
    public static int16 elev {get; private set;}
    public static uint8 fix;

    public GPSInfo(Gtk.Grid grid)
    {
        var lab = new Gtk.Label("No. Satellites");
        lab.halign = Gtk.Align.START;
        lab.valign = Gtk.Align.START;
        grid.attach(lab, 0, 0, 1, 1);
        nsat_lab = new Gtk.Label("-1");
        grid.attach(nsat_lab, 1, 0, 1, 1);

        lab = new Gtk.Label("Latitude");
        lab.halign = Gtk.Align.START;
        lab.valign = Gtk.Align.START;
        grid.attach(lab, 0, 1, 1, 1);
        lat_lab = new Gtk.Label("--.------");
        lat_lab.halign = Gtk.Align.START;
        lat_lab.valign = Gtk.Align.START;
        grid.attach(lat_lab, 1, 1, 1, 1);

        lab = new Gtk.Label("Longitude");
        lab.halign = Gtk.Align.START;
        lab.valign = Gtk.Align.START;
        grid.attach(lab, 0, 2, 1, 1);
        lon_lab = new Gtk.Label("---.------");
        lon_lab.halign = Gtk.Align.START;
        lon_lab.valign = Gtk.Align.START;
        grid.attach(lon_lab, 1, 2, 1, 1);

        lab = new Gtk.Label("Altitude");
        lab.halign = Gtk.Align.START;
        lab.valign = Gtk.Align.START;
        grid.attach(lab, 0, 3, 1, 1);
        alt_lab = new Gtk.Label("---");
        alt_lab.halign = Gtk.Align.START;
        alt_lab.valign = Gtk.Align.START;
        grid.attach(alt_lab, 1, 3, 1, 1);

        lab = new Gtk.Label("Direction");
        lab.halign = Gtk.Align.START;
        lab.valign = Gtk.Align.START;
        grid.attach(lab, 0, 4, 1, 1);
        dirn_lab = new Gtk.Label("---");
        dirn_lab.halign = Gtk.Align.START;
        dirn_lab.valign = Gtk.Align.START;
        grid.attach(dirn_lab, 1, 4, 1, 1);

        lab = new Gtk.Label("Speed");
        lab.halign = Gtk.Align.START;
        lab.valign = Gtk.Align.START;
        grid.attach(lab, 0, 5, 1, 1);
        speed_lab = new Gtk.Label("--.-");
        speed_lab.halign = Gtk.Align.START;
        speed_lab.valign = Gtk.Align.START;
        grid.attach(speed_lab, 1, 5, 1, 1);
        grid.show_all();
    }

    public int update_mav_gps(Mav.MAVLINK_GPS_RAW_INT m, bool dms,bool visible)
    {
        lat = m.lat/10000000.0;
        lon = m.lon/10000000.0;
        double dalt = m.alt/1000.0;
        double cse = (m.cog == 0xffff) ? 0 : m.cog/100.0;
        spd  = (m.vel == 0xffff) ? 0 : m.vel/100.0;
        elev = (int16)Math.lround(dalt);
        nsat = m.satellites_visible;
        fix = m.fix_type;

        var nsatstr = "%d (%sfix)".printf(m.satellites_visible, (m.fix_type < 2) ? "no" : "");
         if(visible)
        {
            nsat_lab.set_label(nsatstr);
            lat_lab.set_label(PosFormat.lat(lat,dms));
            lon_lab.set_label(PosFormat.lon(lon,dms));
            speed_lab.set_label(
                "%.0f %s".printf(
                    Units.speed(spd), Units.speed_units()
                                 ));
            alt_lab.set_label("%.1f %s".printf(
                                  Units.distance(dalt), Units.distance_units()));

            dirn_lab.set_label("%.1f °".printf(cse));
        }

        if(Logger.is_logging)
        {
            Logger.mav_gps_raw_int (m);
        }

        return m.fix_type;
    }


    public int update_ltm(LTM_GFRAME g, bool dms,bool visible)
    {
        lat = g.lat/10000000.0;
        lon = g.lon/10000000.0;
        double cse = 0;
        if(_dlat != 0 && _dlon != 0)
        {
            double d;
            Geo.csedist(_dlat, _dlon, lat, lon, out d, out cse);
        }
        _dlat = lat;
        _dlon = lon;

        spd =  g.speed;
        double dalt = g.alt/100.0;
        fix = (g.sats & 3);
        nsat = (g.sats >> 2);
        var nsatstr = "%d (%sfix)".printf(nsat, Units.fix(fix));
        elev = (int16)Math.lround(dalt);

        if(visible)
        {
            nsat_lab.set_label(nsatstr);
            lat_lab.set_label(PosFormat.lat(lat,dms));
            lon_lab.set_label(PosFormat.lon(lon,dms));
            speed_lab.set_label(
                "%.0f %s".printf(
                    Units.speed(spd), Units.speed_units()
                                 ));
            alt_lab.set_label("%.1f %s".printf(
                                  Units.distance(dalt), Units.distance_units()));

            dirn_lab.set_label("%.1f °".printf(cse));
        }

        if(Logger.is_logging)
        {
            Logger.raw_gps(lat,lon,0,spd, elev, fix, (uint8)nsat);
        }
        return fix;
    }

    public int update(MSP_RAW_GPS g, bool dms, bool visible)
    {
        lat = g.gps_lat/10000000.0;
        lon = g.gps_lon/10000000.0;
        spd = g.gps_speed/100.0;
        cse = g.gps_ground_course/10.0;
        nsat = g.gps_numsat;
        fix = g.gps_fix;

        if(Logger.is_logging)
        {
            Logger.raw_gps(lat,lon,cse,spd,
                           g.gps_altitude,
                           g.gps_fix,
                           g.gps_numsat);
        }

        if(visible)
        {
            var nsatstr = "%d (%sfix)".printf(g.gps_numsat,
                                              (g.gps_fix==0) ? "no" : "");
            nsat_lab.set_label(nsatstr);
            alt_lab.set_label("%0.f %s".printf(
                                  Units.distance(g.gps_altitude),
                                  Units.distance_units()
                                               ));

            lat_lab.set_label(PosFormat.lat(lat,dms));
            lon_lab.set_label(PosFormat.lon(lon,dms));

            speed_lab.set_label("%.1f %s".printf(
                                    Units.speed(spd),
                                    Units.speed_units()
                                    ));
            dirn_lab.set_label("%.1f °".printf(cse));
        }
        return g.gps_fix;
    }

    public void annul()
    {
        nsat_lab.set_label("-1");
        lat_lab.set_label("--.------");
        lon_lab.set_label("---.------");
        alt_lab.set_label("---");
        dirn_lab.set_label("---");
        speed_lab.set_label("--.-");
    }
}
