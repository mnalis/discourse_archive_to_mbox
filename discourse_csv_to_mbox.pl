#!/usr/bin/perl -T
# by Matija Nalis <mnalis-perl@voyager.hr> under AGPLv3+, started 2026015
#
# converts Discourse "user_archive.csv" from user_archive*.zip data export ZIP file to MBOX format to be read in MUAs
#
# requires Text:CSV module (use "apt-get install libtext-csv-perl" on Debian)

use strict;
use warnings;

use Date::Parse;
use POSIX qw(strftime);
use Text::CSV qw ( csv );
use open ':encoding(UTF-8)';
use autodie qw(:all);
use feature 'say';

my $csv_file = 'user_archive.csv';
my $ADD_REF = $ENV{'ADD_REF'} // 1;
my $DISCOURSE_FROM = $ENV{'DISCOURSE_FROM'} // '';

my $user = 'discourse';
my $domain = 'discourse.invalid';
my $emaildesc = undef;
my $replace_domain = 1;


#
# no user serviceable parts below
#

my $VERSION = "discourse_csv_to_mbox.pl v0.93";

my $row;
my %references = ();

# record optional header, if present
sub add_opt_header($) {
    my $h = shift;
    my $v = $row->{$h};
    
    say "X-Discourse-$h: $v" if defined $v;
}

# attempt to use heuristics to add references for e-mail threads
sub add_references($$) {
    my $url = shift;    # in format: https://community.openstreetmap.org/t/greetings/214/3
    my $msgid = shift;

    return if !defined $url or !defined $msgid;

    my ($thread, $msg) = ($url =~ m{^(https?://.+)/(\d+)$});
    #say STDERR "DBG: thread=$thread, $msg=$msg";

    if (!defined($references{$thread})) {
        @{$references{$thread}} = ();            # create empty list of references if this is a first message in the thread
    }

    say "References: " . join ("\n ",  @{$references{$thread}}) if @{$references{$thread}};

    push @{$references{$thread}}, "<$msgid>";

    if (scalar @{$references{$thread}} > 10) {   # the list of references is getting too large, trim it
        splice(@{$references{$thread}}, 1, 1);   # keep 1st and all other elements except 2nd
    }
}

#
# MAIN
#


# instead of "perl -CSD"
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

if ($DISCOURSE_FROM =~ m{^\s*(.+)\s+<(.+)@(.+)>\s*$}) {
    # if e-mail is also specified inside <>, override one autodetected from archive.
    $emaildesc = $1;
    $user = $2;
    $domain = $3;
    $replace_domain = 0;
} else {
    # otherwise, keep autodetected e-mail and only change display-friendly "From"
    $emaildesc = $DISCOURSE_FROM;
}

my $csv = Text::CSV->new({
    binary      => 1,
    strict      => 1,
    auto_diag   => 1,
});

open my $fh, '<', $csv_file or die "Can't open $csv_file: $!";

# read and set up CSV headers
$csv->header ($fh);

# parse CSV body
while ($row = $csv->getline_hr($fh)) {

    my $subject = $row->{'topic_title'} // '(no subject)';
    my $body    = $row->{'post_raw'}    // '(no body)';  #FIXME: also 'post_cooked' for text/html in multipart-alternative?
    my $created = $row->{'created_at'}  // '';
    my $cat     = $row->{'categories'}  // '';
    my $is_pm   = $row->{'is_pm'}       // 'No';
    my $url     = $row->{'url'};
    
    my $subj_prefix = '';
    $subj_prefix = '[PM] ' if $is_pm eq 'Yes'; # mark "private messages" as Discourse does (in other direction)
    if ($cat and $cat ne '-') {
        $cat =~ tr,|,/,;
        $subj_prefix .= "[$cat] "
    }

    if ($replace_domain && defined $url) {
        if ($url =~ m{^https?://([^/]+)/}) { $domain = $1 }
    }

    my $from = "$user\@$domain";
    my $epoch = str2time($created) || time;
    my $date  = strftime("%a %b %d %H:%M:%S %Y", gmtime($epoch));
#    my $msgid = join('.', ($epoch, time, $$, rand(1000), $url)) . '@' . $domain;   # use undermenistic random ID
    my $msgid = join('.', ($epoch, $url)) . '@' . $domain; # semi-permanent ID, for detecting previous messages

    
    $body =~ s/^From /">From "/mg;  # escape any "From " lines if present, to avoid breaking MBOX format

    say "From $user\@$domain $date";
    say "From: $emaildesc <$from>";
    say "Subject: ${subj_prefix}$subject";
    say "Date: $date +0000";
    say "Message-ID: <$msgid>";

    say "X-Converter: Converted from Discourse $csv_file by $VERSION";
    add_opt_header('url');
    add_references($url, $msgid) if $ADD_REF;
    add_opt_header('categories');
    add_opt_header('is_pm');
    add_opt_header('like_count');
    add_opt_header('reply_count');

    say 'Content-Type: text/plain; charset=UTF-8';
    say '';
    say $body;
    say '';
}

close $fh;
