@import "colors.css";

/* One color for every surface and bar */
window,
.background,
decoration,
headerbar,
.titlebar,
.sidebar,
.view,
menubar,
menu,
.menu,
menuitem,
popover,
toolbar,
.toolbar,
.primary-toolbar,
.inline-toolbar,
statusbar,
actionbar,
notebook,
notebook > header,
notebook > header > tabs,
notebook > header > tabs > tab,
notebook > stack,
paned,
box,
scrolledwindow,
viewport,
textview,
textview text,
treeview,
treeview.view,
treeview.view text,
treeview header button {
    background-color: @gtk_bg;
    background-image: none;
    box-shadow: none;
    border-color: @gtk_bg;
}

headerbar,
.titlebar {
    border-bottom: none;
}

/* Text color */
window,
label,
menubar *,
toolbar *,
statusbar *,
notebook tab label,
treeview.view,
textview text {
    color: @gtk_fg;
}

/* Original selection colors, kept for the editor and lists */
textview text selection,
textview selection,
.view text selection,
.view selection,
treeview.view:selected,
treeview.view:selected:focus {
    background-color: #4a6984;
    color: #ffffff;
}
