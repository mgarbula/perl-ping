#!/usr/bin/perl
use strict;
use warnings;

use IO::Socket;
use Time::HiRes qw(time);
use List::Util qw( min max );
use Getopt::Long;

use lib '.';
use ICMP;
use Module;

sub summary {
    my $end_total = time();
    my $total_difference = ($end_total - $main::start_total) * 1000;
    my $loss = 1 - $main::received/$main::transmitted;
    print "--- $main::peer_addr my_ping statistics ---\n";
    print "$main::transmitted packets transmitted, $main::received packets received, $loss% packet loss";
    printf(", time %0.0f ms\n", $total_difference);
    my $min = min @main::times;
    my $max = max @main::times;
    my $avg = Module::avg(@main::times);
    printf("rtt min/avg/max = %0.3f/%0.3f/%0.3f ms\n", $min * 1000, $avg * 1000, $max * 1000);
}

sub help {
    print "\n";
    print "Usage\n  my_ping.pl [options] <destination>\n\n";
    print "Options\n";
    print "<destination>\tdns name or ip address\n";
    print "-c <count>\tstop after <count> replies\n";
    print "-h\t\tdisplay this help\n";
    print "-i <interval>\tseconds between sending each packet\n";
    print "-q\t\tquiet output\n";
    exit;
}

my ($count, $help, $quiet, $interval);
GetOptions(
    'c=i' => \$count,
    'h' => \$help,
    'q' => \$quiet,
    'i=i' => \$interval,
);

if ($help) {
    help();
}

if (!$count) {
    $count = 1000;
}

$SIG{INT} = sub { summary(); exit 1 };

our $peer_addr = $ARGV[0];

if (!$peer_addr) {
    help();
}

our $start_total = time();

my $hostent = gethostbyname($peer_addr) or die "my_ping: $peer_addr: Name or service not known";
my $addr_in = sockaddr_in(0, $hostent);
my $ip = inet_ntoa($hostent);

my ($packet, $id)= Module::create_packet();
my $packet_size = length($packet);

print "MY_PING $peer_addr ($ip) $packet_size bytes of data\n";

our @times;
our $transmitted = 0;
our $received = 0;

my $proto = getprotobyname("icmp");
my $packet_sent = 0;
for my $icmp_seq (1..$count) {
    my $socket = IO::Socket->new(
        Domain => IO::Socket::AF_INET,
        Type => IO::Socket::SOCK_RAW,
        Proto => $proto
    ) or die "new socket: $!\n";

    if ($interval && $packet_sent) {
        sleep($interval - 1);
    }
    my $start = time();
    my $sent = $socket->send($packet, 0, $addr_in) or die "send: $!\n";
    $packet_sent = 1;
    $transmitted++;
    my $recv_buffer = "";

    $socket->recv($recv_buffer, 84) or die "recv: $!\n";
    my $stop = time();
    $received++;
    my $elapsed = $stop - $start;
    push(@times, $elapsed);

    if (Module::verify_reply($recv_buffer, $id) != 0) {
        print "WARNING: received unrelated message!\n";
    }
    if (!$quiet) {
        printf("ping from %s (%s): icmp_seq=%d time=%0.2f ms\n", $peer_addr,
            $ip, $icmp_seq, $elapsed * 1000);
    }
    sleep(1);
}

summary();