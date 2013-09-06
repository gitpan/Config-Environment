# ABSTRACT: Application Configuration via Environment Variables
package Config::Environment;

use utf8;

use Moo;
use Hash::Flatten ();
use Hash::Merge   ();

our $VERSION = '0.000001'; # VERSION


sub BUILDARGS {
    my ($class, @args) = @_;

    unshift @args, 'domain' if $args[0] && !$args[1];
    return {@args};
}

sub BUILD {
    my ($self) = @_;

    return $self->load(\%ENV);
}


has domain => (
    is       => 'ro',
    required => 1
);


sub load {
    my ($self, $hash) = @_;
    my $dom = lc $self->domain;
    my $env = { map {$_ => $hash->{$_}} grep { /^$dom\_/i } keys %{$hash} };
    my $reg = $self->{registry} //= {env => {}, map => {}};
    my $map = $reg->{map};

    for my $key (sort keys %{$env}) {
        my $value = delete $env->{$key};

        $key =~ s/_/./g;
        $key =~ s/^$dom\.//gi;

        my $hash = {lc $key => $value};

        if (ref $value) {
            if ('ARRAY' eq ref $value) {
                my $i = 0;
                $value = { map { ++$i => $_ } @{$value} };
            }

            $hash = Hash::Flatten->new->flatten($value);

            for my $refkey (keys %{$hash}) {
                (my $newref = $refkey) =~ s/(\w):(\d)/"$1.".($2+1)/gpe;
                $hash->{lc "$key.$newref"} = delete $hash->{$refkey};
            }
        }

        $map = Hash::Merge->new('RIGHT_PRECEDENT')->merge(
            $map => Hash::Flatten->new->unflatten($hash)
        );

        # re-setting ... re-formatting
        while (my($key, $val) = each(%{$hash})) {
            $ENV{uc join '_', $self->domain, split /\./, $key} = $val;
        }
    }

    $reg->{map} = $map;

    return $self;
}


sub param {
    my ($self, $key, $val) = @_;

    if (@_ > 2) {
        my $new = uc join '_', $self->domain, split /\./, $key;
        $self->load({$new => $val}); # load actually re-sets env vars
    }

    if (exists $self->{registry}{env}{$key}) {
        return $self->{registry}{env}{$key};
    }
    else {
        my $node  = $self->{registry}{map};
        my @steps = split /\./, $key;
        for (my $i=0; $i<@steps; $i++) {
            my $step = $steps[$i];
            if (exists $node->{$step}) {
                if ($i<@steps && 'HASH' ne ref $node) {
                    return undef;
                }
                $node = $node->{$step};
            }
            else {
                return undef;
            }
        }
        return $self->{registry}{env}{$key} = $node;
    }

    return;
}


sub params {
    my ($self, @keys) = @_;
    my @vals = map { $self->param($_) } @keys;
    return wantarray ? @vals : $vals[0];
}


sub environment {
    my ($self) = @_;
    my $map = Hash::Flatten->new->flatten($self->{registry}{map});

    for my $key (keys %{$map}) {
        $map->{uc join '_', $self->domain, split /\./, $key}
            = delete $map->{$key};
    }

    return $map;
}

1;

__END__

=pod

=head1 NAME

Config::Environment - Application Configuration via Environment Variables

=head1 VERSION

version 0.000001

=head1 SYNOPSIS

    use Config::Environment;

    my $conf = Config::Environment->new('myapp');
    my $conn = $conf->param('db.1.conn' => 'dbi:mysql:dbname=foobar');
    my $user = $conf->param('db.1.user'); # via $ENV{MYAPP_DB_1_USER} or undef
    my $pass = $conf->param('db.1.pass'); # via $ENV{MYAPP_DB_1_PASS} or undef

    or

    my $info = $conf->param('db.1');
    say $info->{conn}; # outputs dbi:mysql:dbname=foobar
    say $info->{user}; # outputs value of $ENV{MYAPP_DB_1_USER}
    say $info->{pass}; # outputs value of $ENV{MYAPP_DB_1_PASS}

    likewise ...

    $conf->param('server' => {node => ['10.10.10.02', '10.10.10.03']});

    creates the following environment variables and assignments

    $ENV{MYAPP_SERVER_NODE_1} = '10.10.10.02'
    $ENV{MYAPP_SERVER_NODE_2} = '10.10.10.03'

    ... and the configuration can be retrieved using any of the following

    $conf->param('server');
    $conf->param('server.node');
    $conf->param('server.node.1');
    $conf->param('server.node.2');

    or

    my ($node1, $node2) = $conf->params(qw(server.node.1 server.node.2));

=head1 DESCRIPTION

Config::Environment is an interface for managing application configuration using
environment variables as a backend. Using environment variables as a means of
application configuration is a great way of controlling which parts of your
application configuration gets hard-coded and shipped with your codebase (and
which parts do not). Additionally, application configuration can be set at the
system, user, and/or application level and easily overridden by using
environment variables. Please note that variable names are handled in a
case-insensative manner.

=head1 ATTRIBUTES

=head2 domain

The domain attribute contains the environment variable prefix used as context
to differentiate between other environment variables.

=head1 METHODS

=head2 load

The load method expects a hashref which it parses and generates environment
variables from whether the exist or not and registers the formatted environment
structure. This method is called automatically on instantiation using the global
ENV hash as an argument.

    $self->load($hash);

=head2 param

The param method expects a key which it uses to locate the corresponding
environment variable in the registered data structure. The key uses dot-notation
to traverse hierarchical data in the registry. This method will return undefined
if no element can be found matching the query. The method can also be used to
set environment variables by passing an additional argument as the value in the
form of a scalar, arrayref or hashref.

    my $item = $self->param($key);
    my $item = $self->param($key => $value);

    $self->param('a.b');
    $self->param('a.b.c');
    $self->param('a.b.c.1');
    $self->param('a.b.c.2');
    $self->param('z.x.y.1.a');
    $self->param('z.x.y.2.a');
    $self->param('z.x.y.3.a');

=head2 params

The params method expects a list of keys which are used to locate the
corresponding environment variables in the registered data structure. The keys
use dot-notation to traverse hierarchical data in the registry and return a list
of corresponding values in order specified. This method returns a list in
list-context, otherwise it returns the first element found of the list of
queries specified.

    my $item  = $self->params(@list_of_keys);
    my @items = $self->params(@list_of_keys);

=head2 environment

The environment method returns a hashref representing all environment variables
specific to the instantiated object's domain and instance.

    my $environment = $self->environment;

=head1 AUTHOR

Al Newkirk <anewkirk@ana.io>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Al Newkirk.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
