#!/usr/bin/python3
"""Launch the current XDG browser, without storing a second browser choice."""
import sys
import gi
gi.require_version('Gio', '2.0')
from gi.repository import Gio
app = Gio.AppInfo.get_default_for_uri_scheme('https')
if app is None:
    app = Gio.AppInfo.get_default_for_uri_scheme('http')
if app is None:
    app = Gio.AppInfo.get_default_for_type('text/html', False)
if app is None:
    raise SystemExit("Aucun navigateur par défaut XDG n'est défini.")
if sys.argv[1:] == ['--print-desktop']:
    print(app.get_id())
elif sys.argv[1:]:
    if any(value.startswith('-') for value in sys.argv[1:]):
        raise SystemExit('Option non prise en charge.')
    app.launch_uris(sys.argv[1:], None)
else:
    app.launch([], None)
