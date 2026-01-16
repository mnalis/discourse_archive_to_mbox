# discourse_archive_to_mbox
Converts to Discourse user_archive.csv to Mailbox file

## Usage:

* unzip your `user_archive-USERNAME-*.zip` to a directory
* run `discourse_csv_to_mbox.pl > output.mbox`

## TODO
* allow user to specify "From" (or even auto-pick from JSON)
* implement `post_cooked` for multipart-alternative text/html
