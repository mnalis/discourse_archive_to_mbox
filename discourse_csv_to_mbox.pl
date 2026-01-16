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

my $user = 'discourse';
my $domain = 'discourse.invalid';
my $replace_domain = 1;
my $ADD_REF = $ENV{'ADD_REF'} // 1;

#
# no user serviceable parts below
#

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

    #my ($proto, $fqdn, $thread, $msg) = ($url =~ m{^(https?)://([^/]+)/(.+)/(\d+)$});
    #say STDERR "DBG: proto=$proto; fqdn=$fqdn; thread=$thread, $msg=$msg";

    my ($thread, $msg) = ($url =~ m{^(https?://.+)/(\d+)$});
    #say STDERR "DBG: thread=$thread, $msg=$msg";
    push @{$references{$thread}}, "<$msgid>";

    if (scalar @{$references{$thread}} > 10) {  # the list of references is getting too large, trim it
        splice(@{$references{$thread}}, 1, 1);   # keep 1st and all other elements except 2nd
    }

    say "References: " . join ("\n ",  @{$references{$thread}});
}

#
# MAIN
#


# instead of "perl -CSD"
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");


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
    my $url     = $row->{'url'};
    
    if ($replace_domain && defined $url) {
        if ($url =~ m{^https?://([^/]+)/}) { $domain = $1 }
    }

    my $epoch = str2time($created) || time;
    my $date  = strftime("%a %b %d %H:%M:%S %Y", gmtime($epoch));
#    my $msgid = join('.', ($epoch, time, $$, rand(1000), $url)) . '@' . $domain;   # use undermenistic random ID
    my $msgid = join('.', ($epoch, $url)) . '@' . $domain; # semi-permanent ID, for detecting previous messages

    
    $body =~ s/^From /">From "/mg;  # escape any "From " lines if present, to avoid breaking MBOX format

    say "From $user\@$domain $date";
    say "From: $user\@$domain";
    say "Subject: $subject";
    say "Date: $date +0000";
    say "Message-ID: <$msgid>";

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
