package Euler424_v1;

use strict;
use warnings;

package Euler424_v1::Coord;

use Moose;

has ['x', 'y'] => (is => 'ro', isa => 'Int', required => 1);

sub next_x
{
    my $self = shift;

    return Euler424_v1::Coord->new({x => $self->x + 1, y => $self->y});
}

sub next_y
{
    my $self = shift;

    return Euler424_v1::Coord->new({x => $self->x, y => $self->y + 1});
}

package Euler424_v1::Hint;

use Moose;

has 'sum' => (is => 'rw', isa => 'Str');
has 'affected_cells' => (is => 'rw', isa => 'ArrayRef',
    default => sub { return []; });

package Euler424_v1::Cell;

use Moose;

has 'gray' => (is => 'rw', isa => 'Bool');
has ['x_hint', 'y_hint'] => (is => 'rw', 'isa' => 'Maybe[Euler424_v1::Hint]');
has 'digit' => (is => 'rw', isa => 'Maybe[Str]');
has ['x_affecting_sum', 'y_affecting_sum'] => (is => 'rw', 'isa' => 'Maybe[Euler424_v1::Coord]');
has 'options' => (is => 'ro', 'isa' => 'HashRef', default => sub { return +{ map { $_ => 1 } 1 .. 9 }; });

sub set_gray
{
    my ($self) = @_;

    $self->gray(1);
    $self->x_hint(undef());
    $self->y_hint(undef());
    $self->digit(undef());

    return;
}

sub set_digit
{
    my ($self,$val) = @_;

    $self->gray(0);
    $self->digit(length$val ? $val : undef());

    return;
}

sub set_hints
{
    my ($self,$args) = @_;

    $self->gray(1);
    my $h = $args->{h};
    $self->x_hint(defined($h) ? Euler424_v1::Hint->new({ sum => $h }) : $h);

    my $v = $args->{v};
    $self->y_hint(defined($v) ? Euler424_v1::Hint->new({ sum => $v }) : $v);

    return;
}


package Euler424_v1::Puzzle;

use Moose;

use KakuroPerms qw/$GENERATED_PERMS/;

my $EMPTY = 0;
my $X = 1;
my $Y = 2;

my $NUM_DIGITS = 10;

has _dirty => (is => 'rw', isa => 'Bool', default => sub { return 0; });
has _found_letters => (is => 'ro', isa => 'HashRef', default => sub { return +{}; });
has _found_digits => (is => 'ro', isa => 'HashRef', default => sub { return +{}; });
has _queue => (is => 'ro', isa => 'ArrayRef', default => sub { return []; });
has 'y_lim' => (is => 'ro', isa => 'Int', required => 1);
has 'x_lim' => (is => 'ro', isa => 'Int', required => 1);
has 'truth_table' => (is => 'rw', default => sub { return [map { [($EMPTY) x $NUM_DIGITS]} (1 .. $NUM_DIGITS)]; });
has 'grid' => (is => 'rw', lazy => 1, default => sub {
        my $self = shift;
        return [map { [map { Euler424_v1::Cell->new; } 1 .. $self->x_lim] }
            1 .. $self->y_lim
        ]
    }
);

# Calc letter index
sub _calc_l_i
{
    my ($self, $letter) = @_;

    return ord($letter) - ord('A');
}

sub cell
{
    my ($self,$coord) = @_;

    return $self->grid->[$coord->y]->[$coord->x];
}

sub populate_from_string
{
    my ($self,$s) = @_;

    $s =~ s#\r?\n?\z#,#;

    my $_process_hint = sub {
        my $hint = shift;
        if (defined($hint))
        {
            $self->_enqueue({ type => '_mark_as_not', d => 0, l => $self->_calc_l_i(substr($hint, 0, 1))});
        }
        return $hint;
    };

    $self->loop(sub {
            my (undef, $cell) = @_;

            if ($s =~ s#\AX,##)
            {
                $cell->set_gray;
            }
            elsif ($s =~ s#\AO,##)
            {
                $cell->set_digit('');
            }
            elsif ($s =~ s#\A([A-J]),##)
            {
                $cell->set_digit($_process_hint->($1));
            }
            elsif ($s =~ s#\A\((?:h([A-J]{1,2}))?,?(?:v([A-J]{1,2}))?\),##)
            {
                my $h = $1;
                my $v = $2;
                $cell->set_hints(
                    {
                        h => $_process_hint->($h || undef()),
                        v => $_process_hint->($v || undef())
                    }
                );
            }
            else
            {
                die "Unknown format for string <<$s>>!";
            }
        }
    );

    if ($s ne '')
    {
        die "Junk in line - <<$s>>!";
    }
    $self->loop(sub {
            my ($coord, $cell) = @_;
            if ($cell->gray)
            {
                foreach my $dir (qw(x y))
                {
                    my $hint_meth = $dir . '_hint';
                    if (defined(my $hint = $cell->$hint_meth))
                    {
                        my $next_meth = 'next_' . $dir;
                        my $next_coord = $coord->$next_meth;
                        my $lim = $dir . '_lim';
                        my $sum_meth = $dir . '_affecting_sum';
                        NEXT_X:
                        while ($next_coord->$dir < $self->$lim)
                        {
                            my $next_cell = $self->cell($next_coord);
                            if ($next_cell->gray)
                            {
                                last NEXT_X;
                            }
                            $next_cell->$sum_meth($coord);
                            push @{$hint->affected_cells}, $next_coord;
                        }
                        continue
                        {
                            $next_coord = $next_coord->$next_meth;
                        }
                    }
                }
            }
        }
    );
    return;
}

use List::Util qw/ first max min /;
use List::MoreUtils qw/ none /;

sub loop
{
    my ($self, $cb) = @_;

    foreach my $y (0 .. $self->y_lim - 1)
    {
        foreach my $x (0 .. $self->x_lim - 1)
        {
            my $coord = Euler424_v1::Coord->new({x => $x, y => $y});
            $cb->($coord, $self->cell($coord));
        }
    }
    return;
}

use v5.16;

sub _process_queue
{
    my ($self) = @_;

    while (defined (my $task = shift(@{$self->_queue})))
    {
        if ($task->{type} eq '_mark_as_yes')
        {
            $self->_mark_as_yes($task->{l}, $task->{d});
        }
        elsif ($task->{type} eq '_mark_as_not')
        {
            $self->_mark_as_not($task->{l}, $task->{d});
        }
        else
        {
            die "Unknown task type";
        }
    }

    return;
}

sub solve
{
    my $self = shift;

    $self->_output_layout;

    my %already_handled;

    # So it will run the first time.
    $self->_dirty(1);

    MAIN:
    while ( (keys (%{$self->_found_letters}) < 10) and $self->_dirty )
    {
        $self->_dirty(0);

        $self->_process_queue;

        $self->loop(sub {
                my (undef, $cell) = @_;
                if ($cell->gray)
                {
                    foreach my $dir (qw(x y))
                    {
                        my $hint_meth = $dir . '_hint';
                        if (defined(my $hint = $cell->$hint_meth))
                        {
                            my $sum = $hint->sum;
                            my $letter;
                            my $digit;
                            if (($letter) = $sum =~ /\A([A-J])/)
                            {
                                if (exists $already_handled{$letter})
                                {
                                    die "Twilly";
                                }
                                my $l_i = $self->_calc_l_i($letter);
                                my $len = length($sum);
                                my $cells_count = scalar @{$hint->affected_cells};

                                my $min_val =
                                (
                                    ((1 + $cells_count)*$cells_count)
                                    >> 1
                                );

                                my $min = $len == 2 ? max(1, int ( $min_val / 10)) : min(9, $min_val);
                                my $max =
                                (
                                    ((9 + 9 - $cells_count + 1)*$cells_count)
                                    >> 1
                                );
                                if (length$max == $len)
                                {
                                    my $max_digit = (first { $self->truth_table->[$l_i]->[$_] == $EMPTY } reverse 0 .. 9);
                                    my $new_sum = $sum =~ s#\Q$letter\E#$max_digit#gr;
                                    my $new_max = substr($max, 0, 1);
                                    if ($new_sum !~ /[A-J]/ and $new_max eq substr($new_sum, 0, 1) and $max < $new_sum)
                                    {
                                        $new_max--;
                                    }
                                    $max = $new_max;
                                }
                                else
                                {
                                    $max = (first { $self->truth_table->[$l_i]->[$_] == $EMPTY } reverse 0 .. 9);
                                }
                                print "Matching $letter [$min..$max]\n";

                                if ($min == $max)
                                {
                                    my $digit = $min;

                                    $already_handled{$letter} = 1;
                                    $self->_mark_as_yes($l_i, $digit);


                                    # A sanity check.
                                    if (0)
                                    {
                                        foreach my $row (@{$self->grid})
                                        {
                                            foreach my $c (@$row)
                                            {
                                                if ($c->gray)
                                                {
                                                    foreach my $dir (qw(x y))
                                                    {
                                                        my $hint_meth = $dir . '_hint';
                                                        if (defined(my $hint = $c->$hint_meth))
                                                        {
                                                            if ($hint->sum =~ /$letter/)
                                                            # if ($hint->sum =~ /B/)
                                                            {
                                                                die "Foobar";
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        print "Sanity check ok.\n";
                                    }
                                }
                                else
                                {
                                    $self->_mark_as_not_out_of_range(
                                        $l_i, $min, $max
                                    );
                                }

                                if ($len == 1)
                                {
                                    $self->_process_partial_sum(
                                        {
                                            hint => $hint,
                                            max => $max,
                                        }
                                    );
                                }
                            }
                            elsif (($letter) = $sum =~ /\A[0-9]([A-J])/)
                            {
                                my $l_i = $self->_calc_l_i($letter);
                                my $cells_count = scalar @{$hint->affected_cells};
                                my $max =
                                (
                                    ((9 + 9 - $cells_count + 1)*$cells_count)
                                    >> 1
                                );

                                if ($max % 10 == 0)
                                {
                                    if ($max == ($sum =~ s#\Q$letter\E#0#gr))
                                    {
                                        $self->_mark_as_yes($l_i, 0);
                                    }
                                }
                            }
                            elsif ($sum =~ /\A[0-9]+\z/)
                            {
                                $self->_process_partial_sum(
                                    {
                                        hint => $hint,
                                        max => $sum,
                                    }
                                );
                                {
                                    my $partial_sum = $sum;
                                    my $bitmask = 0;
                                    my $cells_count = scalar @{$hint->affected_cells};
                                    my $empty_count = $cells_count;
                                    foreach my $c_ (map { $self->cell($_) } @{$hint->affected_cells})
                                    {
                                        if (defined (my $d_ = $c_->digit))
                                        {
                                            if ($d_ =~ /\A[0-9]\z/)
                                            {
                                                $partial_sum -= $d_;
                                                $bitmask |= (1 << ($d_ - 1));
                                                $empty_count--;
                                            }
                                        }
                                    }
                                    my $perms = $GENERATED_PERMS->{$empty_count}->{$partial_sum - $empty_count};
                                    my @p = grep { !($bitmask & $_) } @$perms;
                                    my $total = 0;
                                    foreach my $p (@p)
                                    {
                                        $total |= $p;
                                    }
                                    foreach my $c_ (map { $self->cell($_) } @{$hint->affected_cells})
                                    {
                                        if (!defined ($c_->digit))
                                        {
                                            foreach my $d (1 .. 9)
                                            {
                                                if (!($total & (1 << ($d - 1))))
                                                {
                                                    delete $c_->options->{$d};
                                                }
                                            }

                                            my @k = keys %{$c_->options};
                                            if (@k == 1)
                                            {
                                                $c_->digit($k[0]);
                                            }
                                            elsif (! @k)
                                            {
                                                die "Rarity - no options!";
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        );

        $self->_process_queue;
    }

    # Output the current layout:
    $self->_output_layout;
    return;
}

sub _process_partial_sum
{
    my ($self, $args) = @_;

    my $hint = $args->{hint};
    my $max = $args->{max};

    my $partial_sum = 0;
    my @digits = (1 .. 9);
    my %d = (map { $_ => 1 } @digits);
    my $num_empty = 0;
    my @to_trim;
    my @partial;

    foreach my $c_ (map { $self->cell($_) } @{$hint->affected_cells})
    {
        if (defined (my $d_ = $c_->digit))
        {
            my $d2;
            if ($d_ =~ /\A[0-9]\z/)
            {
                $d2 = $d_;
                delete $d{$d2};
            }
            else
            {
                my $l_i = $self->_calc_l_i($d_);
                V:
                foreach my $v (0 .. 9)
                {
                    if ($self->truth_table->[$l_i]->[$v] == $EMPTY)
                    {
                        $d2 = $v;
                        last V;
                    }
                }
                if (!defined$d2)
                {
                    die "applebloom";
                }
                push @to_trim, +{ l => $l_i, min => $d2, max => (first { $self->truth_table->[$l_i]->[$_] == $EMPTY } reverse 0 .. 9)};
            }
            $partial_sum += $d2;
        }
        else
        {
            my @k = keys %{$c_->options};
            if (@k < 9)
            {
                push @partial, $c_;
            }
            else
            {
                $num_empty++;
            }
        }
    }

    foreach my $i (1 .. $num_empty)
    {
        while (not exists $d{$digits[0]})
        {
            shift@digits;
        }
        $partial_sum += shift@digits;
    }
    foreach my $p (@partial)
    {
        $partial_sum += min(keys%{$p->options});
    }

    if (my ($letter) = $hint->sum =~ /\A([A-J])/)
    {
        $self->_mark_as_not_out_of_range(
            $self->_calc_l_i($letter), $partial_sum, $max
        );
    }

    foreach my $t (@to_trim)
    {
        $self->_mark_as_not_out_of_range(
            $t->{l},
            $t->{min},
            $max - $partial_sum + $t->{min},
        );
    }

    return;
}

sub _output_layout
{
    my $self = shift;

    use Text::Table;

    my $tb = Text::Table->new((map { ; "Col", \' | '; } 2 .. $self->x_lim), "Col");

    my $transform = sub {
        my $item = shift;

        if (! defined($item)) {
            return '';
        }
        elsif (ref$item eq '') {
           return $item =~ s#([A-J])#
                my $l = $1;
                my $l_i = $self->_calc_l_i($l);
                "{$l=[" . join('', grep { $self->truth_table->[$l_i]->[$_] == $EMPTY } 0 .. 9) . "]}"
            #egr;
        }
        elsif ($item->can('sum')) {
            return __SUB__->($item->sum);
        }
        else
        {
            die "PinkiePie";
        }
    };
    $tb->load(
        map
        {
            my $y = $_;
            [ map {
                    my $x = $_;
                    my $coord = Euler424_v1::Coord->new({x => $x, y => $y});
                    my $cell = $self->cell($coord);
                    $cell->gray ? $transform->($cell->y_hint) . " \\ " . $transform->($cell->x_hint) : $transform->($cell->digit);
                } 0 .. $self->x_lim - 1
            ],
        }
        (0 .. $self->y_lim-1)
    );

    print "Current State == <<\n$tb\n>>\n";

    return;
}

sub _mark_as_not_out_of_range
{
    my ($self, $l_i, $min, $max) = @_;

    my %l = (map { $_ => 1 } $min .. $max);

    foreach my $d (0 .. 9)
    {
        if (!exists $l{$d})
        {
            $self->_mark_as_not($l_i, $d);
        }
    }
    return;
}


sub _enqueue
{
    my ($self, $task) = @_;

    push @{$self->_queue}, $task;

    return;
}


sub _mark_as_not
{
    my ($self, $l_i, $d) = @_;

    my $v_ref = \($self->truth_table->[$l_i]->[$d]);
    if ($$v_ref == $X)
    {
        return;
    }
    $self->_dirty(1);

    $$v_ref = $X;

    {
        my @digit_opts = (grep { $self->truth_table->[$_]->[$d] == $EMPTY } 0 .. 9);
        print "Remaining values for digit=$d : " , (join ',', @digit_opts), "\n";
        if (none { $self->truth_table->[$_]->[$d] == $Y } 0 .. 9)
        {
            if (@digit_opts == 1)
            {
                $self->_enqueue({ type => '_mark_as_yes', d => $d, l => $digit_opts[0]});
            }
            elsif (! @digit_opts)
            {
                die "All Xs in digit=$d!";
            }
        }
    }
    {
        my @letter_opts = (grep { $self->truth_table->[$l_i]->[$_] == $EMPTY } 0 .. 9);
        print "Remaining values for letter=$l_i : " , (join ',', @letter_opts),
        "\n";

        if (none { $self->truth_table->[$l_i]->[$_] == $Y } 0 .. 9)

        {
            if (@letter_opts == 1)
            {
                $self->_enqueue({ type => '_mark_as_yes', d => $letter_opts[0], l => $l_i});
            }
            elsif (! @letter_opts)
            {
                die "All Xs in letter=$l_i!";
            }
        }
    }

    return;
}

sub _mark_as_yes
{
    my ($self, $l_i, $digit) = @_;

    my $letter = chr(ord('A') + $l_i);
    my $v_ref = \($self->truth_table->[$l_i]->[$digit]);
    if ($$v_ref == $Y)
    {
        return;
    }
    $self->_dirty(1);
    print "Matching $letter=$digit\n";
    $$v_ref = $Y;
    $self->_found_letters->{$l_i} = $digit;
    $self->_found_digits->{$digit} = $l_i;

    foreach my $d (0 .. 9)
    {
        if ($d != $digit)
        {
            $self->_mark_as_not($l_i, $d);
        }
        if ($d != $l_i)
        {
            $self->_mark_as_not($d, $digit);
        }
    }

    $self->loop(
        sub {
            my (undef,$c) = @_;
            if ($c->gray)
            {
                foreach my $dir (qw(x y))
                {
                    my $hint_meth = $dir . '_hint';
                    if (defined(my $hint = $c->$hint_meth))
                    {
                        $hint->sum(
                            $hint->sum =~ s#\Q$letter\E#$digit#gr
                        );
                    }
                }
            }
            else
            {
                if (defined $c->digit)
                {
                    $c->digit(
                        $c->digit =~ s#\Q$letter\E#$digit#gr
                    );
                }
            }
            return;
        },
    );

    return;
}

1;
