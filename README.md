# discourse_archive_to_mbox
Converts to Discourse user_archive.csv to Mailbox file

It was written to solve the need to have a local archive of own Discourse posts.

See https://meta.discourse.org/t/export-own-messages-to-mbox-format/374643


## Usage:

* unzip your `user_archive-USERNAME-*.zip` to some directory
* run `discourse_csv_to_mbox.pl > output.mbox`
* if you want to overrider From field, use `DISCOURSE_FROM="Some user" discourse_csv_to_mbox.pl > output.mbox`
  or even `DISCOURSE_FROM="Some user <their_email@example.com>" discourse_csv_to_mbox.pl > output.mbox`

## TODO
* try to auto-detect "From:" from `preferences.json` ?
* implement `post_cooked` for multipart-alternative text/html ?
* implement better threading, but archive seems to miss post-ID as in:
  Message-ID: <discourse/post/1192582@community.openstreetmap.org>
  so that would need to be feature-requested first from Discourse
