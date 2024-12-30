#!/usr/bin/perl
package Module;

use List::Util qw(sum);

sub calculate_checksum {
    my ($packet) = @_; 

    my $sum = 0;
    my $len = length($packet);
    my $i = 0;
    
    while ($i < $len - 1) {
        $sum += unpack("n", substr($packet, $i, 2));
        $i += 2;
    }

    if ($i < $len) {
        $sum += ord(substr($packet, $i, 1));
    }

    $sum = ($sum >> 16) + ($sum & 0xFFFF);
    $sum = ($sum >> 16) + ($sum & 0xFFFF);
    $sum += ($sum >> 16);
    return ~($sum);
}

sub create_packet {
    # header
    my $type = $ICMP::ICMP_ECHO;
    my $code = 0;
    my $checksum = 0;
    my $id = $$;
    my $seq = 0;
    my $icmp_hdr = pack("CCnnn", $type, $code, $checksum, $id, $seq);

    # payload
    my $payload_length = 64 - length($icmp_hdr);
    my $payload = "";
    for (my $i = 0; $i < $payload_length; $i++) {
        $payload .= chr(48 + $i); # ASCII code for '0' + $i
    }
    my $packet = $icmp_hdr . $payload;
    $checksum = calculate_checksum($packet);
    
    $icmp_hdr = pack("CCnnn", $type, $code, $checksum, $id, $seq);
    $packet = $icmp_hdr . $payload;
    return ($packet, $id);
}

sub verify_reply {
    my ($packet, $expected_id) = @_;
    my ($res_type, $res_code, $res_sum, $res_id, $res_seq, $res_pay) = unpack("CCnnna", substr($packet, 20));
    if ($res_type != $ICMP::ICMP_REPLY) {
        print "incorrect res_type $res_type\n";
        return -1;
    }
    if ($res_code != 0) {
        print "incorrect res_code $res_code\n";
        return -1;
    }
    if ($res_id != $expected_id) {
        print "incorrect res_id $res_id\n";
        return -1;
    }
    return 0;
}

sub avg {
    return sum(@_)/@_;
}

1;