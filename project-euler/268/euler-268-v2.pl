#!/usr/bin/perl

use strict;
use warnings;

# use integer;
use bytes;

# use Math::BigInt lib => 'GMP';

use List::Util qw(min max sum);
use List::MoreUtils qw();

STDOUT->autoflush(1);

my @primes = map { 0 + $_ } `primes 2 100`;
my @logs = map { log($_) } @primes;

# my $L = (10 ** 16);
my $L = 1_000_000;
# my $L = 1_000;

my $LOG_L = log($L);

my $total = 0;

my $MAX_C = (1 << 25);
my $ITER = 1_000;
my $count = 0;
my $next_iter = $ITER;

my %gross_sizes;

sub f
{
    # $i is index to start from.
    # $c is count.
    # $mul is the product
    my ($i, $c, $mul, $mul_l) = @_;

    # print "\@_ = @_\n";
    if ($mul_l > $LOG_L)
    {
        return;
    }

    if ($i == @primes)
    {
        if (++$count == $next_iter)
        {
            print "Reached $count/$MAX_C\n";
            $next_iter += $ITER;
        }
        if (@$c >= 4)
        {
            my $offset = int( $L / $mul );
            $gross_sizes{"@$c"} = $offset;

            if (0)
            {
                my $sub = $c & 0x1;
                $total += ($c == 4 ? $offset : (($sub ? -1 : 1) * ($c-1) * $offset));
                if (0)
                {
                    my $sub = $c & 0x1;
                    if (1)
                    {
                        for my $x (1 .. $offset)
                        {
                            my $n = $x * $mul;
                            printf "%sN = %d : %s\n",
                            ($sub ? "-" : "+"),
                            $n,
                            join(" ", grep { $n % $_ == 0 } @primes)
                            ;
                        }
                    }

                    if ($sub)
                    {
                        $total -= $offset;
                    }
                    else
                    {
                        $total += $offset;
                    }
                }
            }
        }
    }
    else
    {
        f($i + 1, $c, $mul, $mul_l);
        f($i + 1, [@$c,$i], $mul*$primes[$i], $mul_l + $logs[$i]);
    }
    return;
}

f(0, [], 1, 0);

my %net_sizes;

sub n
{
    my ($c) = @_;

    return $net_sizes{"@$c"} //=
    sub {
        my $size = sub {
            if (!exists($gross_sizes{"@$c"}))
            {
                return 0;
            }
            else
            {
                my $size = $gross_sizes{"@$c"};

                for my $k (keys(%gross_sizes))
                {
                    my %d = (map { $_ => 0 } @$c);

                    my @elems = split/ /, $k;

                    if (@elems == @$c + 1)
                    {
                        my $count = 0;
                        foreach my $e (@elems)
                        {
                            if (exists($d{$e}))
                            {
                                $count++;
                            }
                        }

                        if ($count == @$c)
                        {
                            $size -= n(\@elems);
                        }
                    }
                }

                return $size;
            }
        }->();

        if (@$c == 4)
        {
            $total += $size;
        }

        return $size;
    }->();
}

my $LIM = keys(%gross_sizes);
$count = 0;
foreach my $k (keys(%gross_sizes))
{
    print "Inspecting $count/$LIM\n";
    $count++;
    my @set = split(/ /, $k);
    if (@set == 4)
    {
        n(\@set);
    }
}

# Got 84176 for $L = 1_000_000;
# Should be 77579.
print "total = $total\n";