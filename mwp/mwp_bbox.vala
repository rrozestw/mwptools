using Gtk;

public class  BBoxDialog : Object
{
    private string filename;
    private int nidx;
    private int maxidx;
    private Gtk.Dialog dialog;
    private Gtk.Button bb_cancel;
    private Gtk.Button bb_ok;
    private Gtk.TreeView bb_treeview;
    private Gtk.ListStore bb_liststore;
    private Gtk.ComboBoxText bb_combo;
    private Gtk.FileChooserButton bb_filechooser;
    private Regex regex;
    private Gtk.TreeSelection bb_sel;

    public BBoxDialog(Gtk.Builder builder, int mrtype = 3)
    {
        dialog = builder.get_object ("bb_dialog") as Gtk.Dialog;
        bb_cancel = builder.get_object ("bb_cancel") as Button;
        bb_ok = builder.get_object ("bb_ok") as Button;
        bb_treeview = builder.get_object ("bb_treeview") as TreeView;
        bb_liststore = builder.get_object ("bb_liststore") as Gtk.ListStore;
        bb_filechooser = builder.get_object("bb_filechooser") as FileChooserButton;
        bb_combo = builder.get_object("bb_comboboxtext") as ComboBoxText;
        var filter = new Gtk.FileFilter ();
        filter.set_filter_name ("BB Logs");
        filter.add_pattern ("*.TXT");
        bb_filechooser.add_filter (filter);

        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        bb_filechooser.set_action(FileChooserAction.OPEN);
        bb_filechooser.add_filter (filter);
        bb_filechooser.file_set.connect(() => {
                filename = bb_filechooser.get_filename();
                bb_liststore.clear();
                get_bbox_file_status();
            });

        bb_sel =  bb_treeview.get_selection();

        bb_sel.changed.connect(() => {
                bb_ok.sensitive = true;
            });

        string [] mrtypes = {"marker", "TRI", "QUADP","QUADX", "BI",
            "GIMBAL","Y6","HEX6","FLYING_WING","Y4","HEX6X","OCTOX8",
            "OCTOFLATP","OCTOFLATX","AIRPLANE/SINGLECOPTER,DUALCOPTER",
            "HELI_120","HELI_90","VTAIL4","HEX6H" };

        foreach(var ts in mrtypes)
            bb_combo.append_text (ts);
        bb_combo.active = mrtype;
        try {
            regex = new Regex ("^Log\\s+(\\d+)\\s+of\\s+(\\d+),.* duration (\\S+)$");
        } catch(Error e) {
            stderr.printf("err: %s", e.message);
        }
    }

    private void get_bbox_file_status()
    {
        nidx = 1;
        maxidx = -1;
        spawn_decoder();
        bb_ok.sensitive = false;
    }

    private void spawn_decoder()
    {
        try {
            string[] spawn_args = {"blackbox_decode", "--stdout",
                                   "--index", "%d".printf(nidx),
                                   filename};
            Pid child_pid;
            int p_stderr;

            Process.spawn_async_with_pipes ("/",
                                            spawn_args,
                                            null,
                                            SpawnFlags.SEARCH_PATH |
                                            SpawnFlags.DO_NOT_REAP_CHILD |
                                            SpawnFlags.STDOUT_TO_DEV_NULL,
                                            null,
                                            out child_pid,
                                            null,
                                            null,
                                            out p_stderr);

		// stderr:
		IOChannel error = new IOChannel.unix_new (p_stderr);
		error.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
                        MatchInfo mi;
                        Gtk.TreeIter iter;
                        if (condition == IOCondition.HUP)
                            return false;
                        try {
                            string line;
                            channel.read_line (out line, null, null);
                            if(regex.match(line, 0, out mi))
                            {
                                nidx = int.parse(mi.fetch(1));
                                maxidx = int.parse(mi.fetch(2));
                                var dura =  mi.fetch(3);
                                bb_liststore.append (out iter);
                                bb_liststore.set (iter, 0, nidx, 1, dura);
                            }
                        } catch (IOChannelError e) {
                            return false;
                        } catch (ConvertError e) {
                            return false;
                        }
                        return true;
                    });
		ChildWatch.add (child_pid, (pid, status) => {
			Process.close_pid (pid);
                        Posix.close(p_stderr);
                        if(nidx == maxidx)
                        {
                            if((int)bb_liststore.iter_n_children(null) == 1)
                            {
                                Gtk.TreeIter iter;
                                Gtk.TreePath path = new Gtk.TreePath.from_string ("0");
                                bb_liststore.get_iter (out iter, path);
                                bb_sel.select_iter(iter);
                            }
                        }
                        else
                        {
                            nidx++;
                            spawn_decoder();
                        }

                    });
	} catch (SpawnError e) {
	}
    }

    public int run()
    {
        dialog.show_all ();
        var id = dialog.run();
        dialog.hide();
        return id;
    }

    public void get_result(out string _name, out int _index, out int _type)
    {
        _name = filename;
        Gtk.TreeModel model;
        Gtk.TreeIter iter;
        bb_sel.get_selected (out model, out iter);
        Value cell;
        model.get_value (iter, 0, out cell);
        _index = (int)cell;
        _type = bb_combo.active;
    }
}